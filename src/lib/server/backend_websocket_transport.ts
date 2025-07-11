// @slop Claude Opus 4

import type {WSContext} from 'hono/ws';

import {create_uuid, Uuid} from '$lib/zod_helpers.js';
import type {Transport} from '$lib/transports.js';
import type {
	Jsonrpc_Message_From_Client_To_Server,
	Jsonrpc_Message_From_Server_To_Client,
	Jsonrpc_Notification,
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
} from '$lib/jsonrpc.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';

// TODO support a SSE backend transport

export class Backend_Websocket_Transport implements Transport {
	readonly transport_name = 'backend_websocket_rpc' as const;

	// Map connection IDs to WebSocket contexts
	#connections: Map<Uuid, WSContext> = new Map();

	// Reverse map to find connection ID by socket
	#connection_ids: WeakMap<WSContext, Uuid> = new WeakMap();

	/**
	 * Add a new WebSocket connection.
	 */
	add_connection(ws: WSContext): Uuid {
		const connection_id = create_uuid();
		this.#connections.set(connection_id, ws);
		this.#connection_ids.set(ws, connection_id);
		return connection_id;
	}

	/**
	 * Remove a WebSocket connection.
	 */
	remove_connection(ws: WSContext): void {
		const connection_id = this.#connection_ids.get(ws);
		if (connection_id) {
			this.#connections.delete(connection_id);
			this.#connection_ids.delete(ws);
		}
	}

	async send(message: Jsonrpc_Request): Promise<Jsonrpc_Response_Or_Error>;
	async send(message: Jsonrpc_Notification): Promise<null>;
	async send(
		message: Jsonrpc_Message_From_Client_To_Server,
	): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		// TODO currently just broadcasts all messages to all clients, the transport abstraction is still a WIP
		if ('id' in message) {
			throw jsonrpc_errors.internal_error(
				'Backend WebSocket transport cannot send requests expecting responses',
			);
		}

		await this.#broadcast(message);
		return null;
	}

	// TODO refactor something like this with `send`
	// async #send_to_connection(
	// 	message: Jsonrpc_Message_From_Server_To_Client,
	// 	connection_id: Uuid,
	// ): Promise<void> {
	// 	const ws = this.#connections.get(connection_id);
	// 	if (!ws) {
	// 		throw jsonrpc_errors.internal_error(`Connection not found: ${connection_id}`);
	// 	}

	// 	ws.send(JSON.stringify(message));
	// }

	/**
	 * Broadcast a message to all connected clients.
	 */
	#broadcast(message: Jsonrpc_Message_From_Server_To_Client): Promise<void> {
		const serialized = JSON.stringify(message);
		for (const ws of this.#connections.values()) {
			try {
				ws.send(serialized);
			} catch (error) {
				console.error('[backend websocket transport] Error broadcasting to client:', error);
			}
		}
		// TODO hack - remove if not ever needed, I assume this will need to be async so let's hold that assumption
		return Promise.resolve();
	}

	is_ready(): boolean {
		return this.#connections.size > 0;
	}

	// get_connection_id(ws: WSContext): Uuid | undefined {
	// 	return this.#connection_ids.get(ws);
	// }

	// get connection_count(): number {
	// 	return this.#connections.size;
	// }

	// get_connection_ids(): Array<Uuid> {
	// 	return Array.from(this.#connections.keys());
	// }
}
