// @slop claude_opus_4

import type {WSContext} from 'hono/ws';

import {create_uuid, Uuid} from '$lib/zod_helpers.js';
import type {Transport} from '$lib/transports.js';
import type {
	Jsonrpc_Batch_Request,
	Jsonrpc_Batch_Response,
	Jsonrpc_Message_From_Client_To_Server,
	Jsonrpc_Message_From_Server_To_Client,
	Jsonrpc_Notification,
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
} from '$lib/jsonrpc.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';

/**
 * Backend WebSocket transport that manages multiple client connections.
 * Can send to specific connections or broadcast to all.
 */
export class Backend_Websocket_Transport implements Transport {
	// TODO BLOCK @api maybe should be `'backend_websocket_rpc'` so they can coexist as needed?
	// or is it useful as is? maybe should let both exist
	// so we can have more sophisticated transport selection?
	readonly type = 'websocket_rpc' as const;

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

	/**
	 * Get connection ID for a WebSocket.
	 */
	get_connection_id(ws: WSContext): Uuid | undefined {
		return this.#connection_ids.get(ws);
	}

	// TODO currently just broadcasts all messages to all clients
	async send(message: Jsonrpc_Request): Promise<Jsonrpc_Response_Or_Error>;
	async send(message: Jsonrpc_Notification): Promise<null>;
	async send(message: Jsonrpc_Batch_Request): Promise<Jsonrpc_Batch_Response>;
	async send(
		message: Jsonrpc_Message_From_Client_To_Server,
	): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		// Backend sends notifications to all connected clients
		// It doesn't expect responses from broadcast messages
		if ('id' in message) {
			throw jsonrpc_errors.internal_error(
				'Backend WebSocket transport cannot send requests expecting responses',
			);
		}

		await this.broadcast(message as Jsonrpc_Notification);
		return null;
	}

	// TODO refactor something like this with `send`
	// async send_to_connection(
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
	broadcast(message: Jsonrpc_Message_From_Server_To_Client): Promise<void> {
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

	/**
	 * Get the number of active connections.
	 */
	get connection_count(): number {
		return this.#connections.size;
	}

	/**
	 * Get all connection IDs.
	 */
	get_connection_ids(): Array<Uuid> {
		return Array.from(this.#connections.keys());
	}
}
