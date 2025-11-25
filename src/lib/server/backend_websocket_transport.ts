// @slop Claude Opus 4

import type {WSContext} from 'hono/ws';

import {create_uuid, Uuid} from '$lib/zod_helpers.js';
import type {Transport} from '$lib/transports.js';
import type {
	JsonrpcMessageFromClientToServer,
	JsonrpcMessageFromServerToClient,
	JsonrpcNotification,
	JsonrpcRequest,
	JsonrpcResponseOrError,
	JsonrpcErrorMessage,
} from '$lib/jsonrpc.js';
import {jsonrpc_error_messages} from '$lib/jsonrpc_errors.js';
import {
	create_jsonrpc_error_message,
	to_jsonrpc_message_id,
	is_jsonrpc_request,
} from '$lib/jsonrpc_helpers.js';

// TODO support a SSE backend transport

export class BackendWebsocketTransport implements Transport {
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

	// TODO needs implementation, only broadcasts notifications for now
	async send(message: JsonrpcRequest): Promise<JsonrpcResponseOrError>;
	async send(message: JsonrpcNotification): Promise<JsonrpcErrorMessage | null>;
	async send(
		message: JsonrpcMessageFromClientToServer,
	): Promise<JsonrpcMessageFromServerToClient | null> {
		// TODO currently just broadcasts all messages to all clients, the transport abstraction is still a WIP
		if (is_jsonrpc_request(message)) {
			return create_jsonrpc_error_message(
				message.id,
				// TODO maybe use a not yet implemented error message?
				jsonrpc_error_messages.internal_error(
					'TODO not yet implemented - backend WebSocket transport cannot send requests expecting responses yet',
				),
			);
		}

		try {
			await this.#broadcast(message);
			return null;
		} catch (error) {
			return create_jsonrpc_error_message(
				to_jsonrpc_message_id(message),
				jsonrpc_error_messages.internal_error(
					error instanceof Error ? error.message : 'failed to broadcast notification',
				),
			);
		}
	}

	// TODO refactor something like this with `send`
	// async #send_to_connection(
	// 	message: JsonrpcMessageFromServerToClient,
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
	#broadcast(message: JsonrpcMessageFromServerToClient): Promise<void> {
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
