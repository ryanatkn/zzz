// @slop claude_opus_4

import type {Socket} from '$lib/socket.svelte.js';
import {Request_Tracker} from '$lib/request_tracker.svelte.js';
import {Jsonrpc_Error, jsonrpc_errors} from '$lib/jsonrpc_errors.js';
import {
	is_jsonrpc_notification,
	is_jsonrpc_request,
	is_jsonrpc_response,
	is_jsonrpc_error_message,
} from '$lib/jsonrpc_helpers.js';
import type {
	Jsonrpc_Batch_Request,
	Jsonrpc_Batch_Response,
	Jsonrpc_Message_From_Client_To_Server,
	Jsonrpc_Message_From_Server_To_Client,
	Jsonrpc_Notification,
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
} from '$lib/jsonrpc.js';
import type {Transport} from '$lib/transports.js';

export class Frontend_Websocket_Transport implements Transport {
	readonly transport_name = 'frontend_websocket_rpc' as const;

	#socket: Socket;
	#request_tracker: Request_Tracker;

	constructor(socket: Socket, request_timeout_ms?: number) {
		this.#socket = socket;
		this.#request_tracker = new Request_Tracker(request_timeout_ms);

		// Set up the message handler
		socket.onmessage = async (event) => {
			try {
				const data = JSON.parse(event.data);

				// TODO the `data.id !== null` check should be refactored, maybe we want the "Error Message Response" concept for non-null ids
				// Check if this is a response to one of our requests
				if (is_jsonrpc_response(data) || (is_jsonrpc_error_message(data) && data.id !== null)) {
					// This is a response to a request we sent
					this.#request_tracker.handle_message(data);
				} else if (is_jsonrpc_request(data) || is_jsonrpc_notification(data)) {
					// This is a new request/notification from the server
					// TODO @many check if batches need special handling here
					await socket.app.peer.receive(data);
				} else {
					console.warn('[frontend websocket transport] Received unknown message type:', data);
				}
			} catch (error) {
				console.error('[frontend websocket transport] Error parsing WebSocket message:', error);
			}
		};
	}

	async send(message: Jsonrpc_Request): Promise<Jsonrpc_Response_Or_Error>;
	async send(message: Jsonrpc_Notification): Promise<null>;
	async send(message: Jsonrpc_Batch_Request): Promise<Jsonrpc_Batch_Response>;
	async send(
		message: Jsonrpc_Message_From_Client_To_Server,
	): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		console.log(`[frontend websocket transport] data`, message);
		if (!this.is_ready()) {
			throw jsonrpc_errors.service_unavailable_error('WebSocket not connected');
		}

		try {
			// If this is a JSON-RPC request with an id (not a notification), set up request tracking.
			if (is_jsonrpc_request(message)) {
				// TODO track the whole request?
				const deferred = this.#request_tracker.track_request(message.id);
				this.#socket.send(message);

				// Return the promise that will resolve when the response is received
				const result = await deferred.promise;
				console.log(`result`, message, result);
				return result;
			} else if (is_jsonrpc_notification(message)) {
				// For notifications, just send without tracking
				this.#socket.send(message);
				return null;
			}
			throw jsonrpc_errors.invalid_request();
		} catch (error) {
			console.error('[frontend websocket transport] Error sending message:', error);
			if (error instanceof Jsonrpc_Error) {
				throw error;
			}
			throw jsonrpc_errors.internal_error(
				error instanceof Error ? error.message : 'Unknown error sending WebSocket message',
			);
		}
	}

	is_ready(): boolean {
		return this.#socket.connected;
	}
}
