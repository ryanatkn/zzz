// @slop Claude Opus 4

import type {Socket} from '$lib/socket.svelte.js';
import {Request_Tracker} from '$lib/request_tracker.svelte.js';
import {Thrown_Jsonrpc_Error, jsonrpc_error_messages} from '$lib/jsonrpc_errors.js';
import {
	is_jsonrpc_notification,
	is_jsonrpc_request,
	is_jsonrpc_response,
	is_jsonrpc_error_message,
	to_jsonrpc_message_id,
	create_jsonrpc_error_message,
} from '$lib/jsonrpc_helpers.js';
import type {
	Jsonrpc_Message_From_Client_To_Server,
	Jsonrpc_Message_From_Server_To_Client,
	Jsonrpc_Notification,
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
	Jsonrpc_Error_Message,
} from '$lib/jsonrpc.js';
import type {Transport} from '$lib/transports.js';
import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';

// TODO logging - maybe add a getter to Cell that falls back to the app logger?

export class Frontend_Websocket_Transport implements Transport {
	readonly transport_name = 'frontend_websocket_rpc' as const;

	#socket: Socket;
	#request_tracker: Request_Tracker;
	#remove_message_handler: (() => void) | null;
	#remove_error_handler: (() => void) | null;

	constructor(socket: Socket, request_timeout_ms?: number) {
		this.#socket = socket;
		this.#request_tracker = new Request_Tracker(request_timeout_ms);

		// TODO maybe we want to do this setup elsewhere, not hardcoded like this
		this.#remove_message_handler = socket.add_message_handler(async (event) => {
			try {
				const data = JSON.parse(event.data);

				// TODO the `data.id !== null` check should be refactored, maybe we want the "Error Message Response" concept for non-null ids
				// Check if this is a response to one of our requests
				if (is_jsonrpc_response(data) || (is_jsonrpc_error_message(data) && data.id !== null)) {
					// This is a response to a request we sent
					this.#request_tracker.handle_message(data);
				} else if (is_jsonrpc_request(data) || is_jsonrpc_notification(data)) {
					// This is a new request/notification from the server
					await socket.app.peer.receive(data);
				} else {
					console.warn('[ws_transport] received unknown message type:', data);
				}
			} catch (error) {
				console.error('[ws_transport] error parsing WebSocket message:', error);
				// TODO maybe send the whole thing back wrapped in an error?
				// can't reference anything else for a response
			}
		});

		this.#remove_error_handler = socket.add_error_handler((event) => {
			console.error('[ws_transport] WebSocket error:', event);
		});
	}

	async send(message: Jsonrpc_Request): Promise<Jsonrpc_Response_Or_Error>;
	async send(message: Jsonrpc_Notification): Promise<Jsonrpc_Error_Message | null>;
	async send(
		message: Jsonrpc_Message_From_Client_To_Server,
	): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		if (!this.is_ready()) {
			return create_jsonrpc_error_message(
				to_jsonrpc_message_id(message),
				jsonrpc_error_messages.service_unavailable('WebSocket not connected'),
			);
		}

		try {
			// If this is a JSON-RPC request with an id (not a notification), set up request tracking.
			if (is_jsonrpc_request(message)) {
				// TODO track the whole request?
				const deferred = this.#request_tracker.track_request(message.id);
				this.#socket.send(message);

				// Return the promise that will resolve when the response is received
				const result = await deferred.promise;
				return result;
			} else if (is_jsonrpc_notification(message)) {
				// For notifications, just send without tracking
				this.#socket.send(message);
				return null;
			}
			// Invalid message type - return error with id if available
			return create_jsonrpc_error_message(
				to_jsonrpc_message_id(message),
				jsonrpc_error_messages.invalid_request(),
			);
		} catch (error) {
			if (error instanceof Thrown_Jsonrpc_Error) {
				return create_jsonrpc_error_message(to_jsonrpc_message_id(message), {
					code: error.code,
					message: error.message,
					data: error.data,
				});
			}
			return create_jsonrpc_error_message(
				to_jsonrpc_message_id(message),
				jsonrpc_error_messages.internal_error(error.message || UNKNOWN_ERROR_MESSAGE),
			);
		}
	}

	is_ready(): boolean {
		return this.#socket.connected;
	}

	// TODO ? not called, maybe add to base class?
	dispose(): void {
		if (this.#remove_message_handler) {
			this.#remove_message_handler();
			this.#remove_message_handler = null;
		}
		if (this.#remove_error_handler) {
			this.#remove_error_handler();
			this.#remove_error_handler = null;
		}
	}
}
