import {create_deferred, type Deferred, type Async_Status} from '@ryanatkn/belt/async.js';

import {create_uuid, get_datetime_now, Uuid} from '$lib/zod_helpers.js';
import type {Action_Method} from '$lib/action_metatypes.js';
import type {Action_Message_From_Server} from '$lib/action_collections.js';
import type {Socket} from '$lib/socket.svelte.js';
import {create_jsonrpc_request} from '$lib/jsonrpc_helpers.js';
import type {Api_Params} from '$lib/api.js';
import {
	Http_Rpc_Transport,
	Transports,
	Websocket_Rpc_Transport,
	type Transport_Type,
} from '$lib/transport.js';

// TODO support canceling

export interface Api_Client_Options {
	http_url?: string | null; // TODO optional thunk?
	http_headers?: Record<string, string>; // TODO optional thunk?
	socket?: Socket | null;
	default_transport_type?: Transport_Type; // TODO optional thunk?
	onreceive: (method: string, params: Api_Params, id?: Uuid) => void;
	onsend: (method: string, params: Api_Params, id?: Uuid) => void;
}

export interface Request_Tracker<T> {
	deferred: Deferred<T>;
	method: string;
	created: string;
	status: Async_Status;
	timeout?: NodeJS.Timeout;
}

/**
 * Client for communicating with the Zzz server.
 * Uses JSON-RPC for both HTTP and WebSocket communication.
 */
export class Api_Client {
	readonly transports = new Transports();

	/** Callback triggered when receiving a message from the server. */
	#onreceive: (method: string, params: Api_Params, id?: Uuid) => void;

	/** Callback triggered before sending a message. */
	readonly #onsend: (method: string, params: Api_Params, id?: Uuid) => void;

	readonly #pending_requests: Map<string, Request_Tracker<any>> = new Map();

	readonly #request_timeout_ms = 30000;

	constructor(options: Api_Client_Options) {
		this.#onreceive = options.onreceive;
		this.#onsend = options.onsend;

		// Set up HTTP transport if URL is provided
		if (options.http_url) {
			this.transports.register_transport(
				new Http_Rpc_Transport(
					options.http_url,
					this.#handle_incoming_message,
					options.http_headers,
				),
			);
		}

		// Set up WebSocket transport if socket is provided
		if (options.socket) {
			this.transports.register_transport(
				new Websocket_Rpc_Transport(options.socket, this.#handle_incoming_message),
			);
			this.transports.set_current_transport('websocket_rpc'); // prefer if available
		}

		if (options.default_transport_type) {
			this.transports.set_current_transport(options.default_transport_type);
		}
	}

	/**
	 * Send an action to the server and get a response.
	 */
	async send_action<T = any>(
		method: Action_Method,
		params: Api_Params,
		id: Uuid = create_uuid(),
		transport_type?: Transport_Type,
	): Promise<T> {
		this.#onsend(method, params, id);

		// Create a deferred promise to track this request
		const deferred = this.#track_request<T>(id, method);

		// Send the request
		try {
			const message = create_jsonrpc_request(method, params, id);
			const transport = this.transports.get_or_throw(transport_type);
			await transport.send(message);
		} catch (error) {
			// Remove the pending request and reject the promise
			this.#reject_pending_request(id, error);
			throw error;
		}

		// Return the promise that will be resolved when the response is received
		return deferred.promise;
	}

	// TODO BLOCK @api is this a transport concern?
	/**
	 * Processes a received action message from server.
	 * This is the primary entry point for handling incoming server messages.
	 */
	receive_incoming_message(message: Action_Message_From_Server): void {
		const {id, method, params} = message;

		// First check if this is a response to a pending request
		const pending_request = id ? this.#pending_requests.get(id) : undefined;
		if (pending_request) {
			this.#resolve_pending_request(id, message);
			return;
		}

		// TODO BLOCK hacky, need to clarify the role of this class
		// Otherwise, it's a server-initiated message, pass to onreceive
		this.#onreceive(method, params, id);
	}

	#handle_incoming_message = (message: any): void => {
		// JSON-RPC response
		if (message.id && (message.result !== undefined || message.error !== undefined)) {
			const id = message.id;
			if (message.error) {
				this.#reject_pending_request(id, message.error);
			} else {
				this.#resolve_pending_request(id, message.result);
			}
			// TODO BLOCK this doesn't seem right, need to clarify api_client vs zzz vs actions
			return;
		}

		// JSON-RPC request/notification from server
		if (message.method) {
			const {id, method, params} = message;

			this.#onreceive(method, params, id);
		}
	};

	#resolve_pending_request(id: string, response: any): void {
		const request = this.#pending_requests.get(id);
		if (!request) {
			console.warn(`Received response for unknown request: ${id}`);
			return;
		}

		// Clear the timeout and resolve the promise
		if (request.timeout) {
			clearTimeout(request.timeout);
		}

		request.status = 'success';
		request.deferred.resolve(response);
		this.#pending_requests.delete(id);
	}

	#reject_pending_request(id: string, error: any): void {
		const request = this.#pending_requests.get(id);
		if (!request) {
			console.warn(`Received error for unknown request: ${id}`);
			return;
		}

		// Clear the timeout and reject the promise
		if (request.timeout) {
			clearTimeout(request.timeout);
		}

		request.status = 'failure';
		request.deferred.reject(error);
		this.#pending_requests.delete(id);
	}

	#track_request<T>(id: string, method: string): Deferred<T> {
		const deferred = create_deferred<T>();
		const created = get_datetime_now();

		// Set up a timeout to automatically reject the request after a delay
		const timeout = setTimeout(() => {
			const request = this.#pending_requests.get(id);
			if (request) {
				request.status = 'failure';
				request.deferred.reject(new Error(`Request timed out: ${method}`));
				this.#pending_requests.delete(id);
			}
		}, this.#request_timeout_ms);

		// Store the request tracker
		this.#pending_requests.set(id, {
			deferred,
			method,
			created,
			status: 'pending',
			timeout,
		});

		return deferred;
	}
}
