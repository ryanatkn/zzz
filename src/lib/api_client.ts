import {create_deferred, type Deferred, type Async_Status} from '@ryanatkn/belt/async.js';

import {create_uuid, get_datetime_now} from '$lib/zod_helpers.js';
import type {Action_Method} from '$lib/action_metatypes.js';
import type {Action_Message_From_Server} from '$lib/action_collections.js';
import type {Socket} from '$lib/socket.svelte.js';
import {Jsonrpc_Client} from '$lib/jsonrpc_client.js';
import type {JSONRPCMessage} from '$lib/jsonrpc.js';
import type {Api_Transport} from '$lib/api.js';
import type {Zzz} from '$lib/zzz.svelte.js';

export interface Api_Transport_Provider {
	type: Api_Transport;
	send: (data: JSONRPCMessage) => void;
	is_ready: () => boolean;
}

export interface Api_Client_Options<T_Zzz extends Zzz = Zzz> {
	zzz: T_Zzz;

	/** Endpoint for http transport. */
	http_url?: string;

	/** Socket instance for websocket transport. */
	socket?: Socket;

	/** Default transport method to use */
	default_transport?: Api_Transport;

	/** Callback for handling server messages */
	onreceive?: (method: string, params: Record<string, any> | void, id?: string) => void;

	/** Callback triggered before sending a message */
	onsend?: (method: string, params: Record<string, any> | void, id?: string) => void;
}

export interface Request_Tracker<T> {
	/** Deferred promise that will be resolved when the response is received */
	deferred: Deferred<T>;

	/** Method that was called */
	method: string;

	/** When the request was created */
	created: string;

	/** Request status */
	status: Async_Status;

	/** Timeout for request expiration */
	timeout?: NodeJS.Timeout;
}

/**
 * Client for communicating with the Zzz server.
 * Uses JSON-RPC for both HTTP and WebSocket communication.
 */
export class Api_Client<T_Zzz extends Zzz = Zzz> {
	readonly zzz: T_Zzz;

	/** JSON-RPC client for communication */
	readonly jsonrpc_client = new Jsonrpc_Client();

	/** Socket instance for WebSocket transport */
	readonly #socket?: Socket;

	/** Callback triggered when receiving a message from the server */
	#onreceive?: (method: string, params: Record<string, any> | void, id?: string) => void;

	/** Callback triggered before sending a message */
	readonly #onsend?: (method: string, params: Record<string, any> | void, id?: string) => void;

	readonly #pending_requests: Map<string, Request_Tracker<any>> = new Map();

	readonly #request_timeout_ms = 30000;

	constructor(options: Api_Client_Options<T_Zzz>) {
		this.zzz = options.zzz;
		this.#socket = options.socket;
		this.#onreceive = options.onreceive;
		this.#onsend = options.onsend;

		// Set up HTTP transport if URL is provided
		if (options.http_url) {
			const http_transport = new Http_Api_Transport_Provider(
				options.http_url,
				this.#handle_incoming_message.bind(this),
			);
			this.jsonrpc_client.register_transport('http', http_transport);
		}

		// Set up WebSocket transport if socket is provided
		if (this.#socket) {
			const socket_transport = this.#create_socket_transport();
			if (socket_transport) {
				this.jsonrpc_client.register_transport('websocket', socket_transport);
			}
		}
	}

	/**
	 * Handle incoming messages from the server
	 */
	#handle_incoming_message(message: any): void {
		// JSON-RPC response
		if (message.id && (message.result !== undefined || message.error !== undefined)) {
			const id = message.id;
			if (message.error) {
				this.#reject_pending_request(id, message.error);
			} else {
				this.#resolve_pending_request(id, message.result);
			}
			return;
		}

		// JSON-RPC request/notification from server
		if (message.method) {
			const {id, method, params} = message;

			// Call the onreceive handler if provided
			if (this.#onreceive) {
				this.#onreceive(method, params, id);
			}
		}
	}

	/**
	 * Resolve a pending request with a response
	 */
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

	/**
	 * Reject a pending request with an error
	 */
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

	/**
	 * Create a WebSocket transport provider that uses the Socket class
	 */
	#create_socket_transport(): Api_Transport_Provider | null {
		if (!this.#socket) {
			return null;
		}

		return new Socket_Api_Transport_Provider(
			this.#socket,
			this.#handle_incoming_message.bind(this),
		);
	}

	/**
	 * Track a new request with timeout
	 */
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

	/**
	 * Send an action to the server and get a response
	 */
	async send_action<T = any>(
		method: Action_Method,
		params: Record<string, any> = {},
		id: string = create_uuid(),
		transport?: Api_Transport,
	): Promise<T> {
		// Call the onsend handler if provided
		if (this.#onsend) {
			this.#onsend(method, params, id);
		}

		// Create a deferred promise to track this request
		const deferred = this.#track_request<T>(id, method);

		// Send the request
		try {
			this.jsonrpc_client.send(method, params, id, transport);
		} catch (error) {
			// Remove the pending request and reject the promise
			this.#reject_pending_request(id, error);
			throw error;
		}

		// Return the promise that will be resolved when the response is received
		return deferred.promise;
	}

	/**
	 * Send a notification to the server (no response expected)
	 */
	notify(method: Action_Method, params: Record<string, any> = {}): void {
		// Call the onsend handler if provided
		if (this.#onsend) {
			this.#onsend(method, params);
		}

		try {
			this.jsonrpc_client.notify(method, params);
		} catch (error) {
			console.error('Error sending notification:', error);
			throw error;
		}
	}

	/**
	 * Processes a received action message from server.
	 * This is the primary entry point for handling incoming server messages.
	 */
	handle_incoming_message(message: Action_Message_From_Server): void {
		const {id, method, params} = message;

		// First check if this is a response to a pending request
		const pending_request = id ? this.#pending_requests.get(id) : undefined;
		if (pending_request) {
			this.#resolve_pending_request(id, message);
			return;
		}

		// Otherwise, it's a server-initiated message, pass to onreceive
		if (this.#onreceive) {
			this.#onreceive(method, params, id);
		}
	}
}

/**
 * WebSocket transport provider that uses the Socket class
 */
export class Socket_Api_Transport_Provider implements Api_Transport_Provider {
	readonly type = 'websocket' as const;

	#socket: Socket;
	#on_message: (data: any) => void;

	constructor(socket: Socket, on_message: (data: any) => void) {
		this.#socket = socket;
		this.#on_message = on_message;

		// Set up the message handler
		socket.onmessage = (event) => {
			try {
				const data = JSON.parse(event.data);
				this.#on_message(data);
			} catch (error) {
				console.error('Error parsing WebSocket message:', error);
			}
		};
	}

	send(data: JSONRPCMessage): void {
		if (!this.is_ready()) {
			throw new Error('WebSocket not connected');
		}
		this.#socket.send(data);
	}

	is_ready(): boolean {
		return this.#socket.connected;
	}
}

/**
 * HTTP transport provider for REST API calls
 */
export class Http_Api_Transport_Provider implements Api_Transport_Provider {
	readonly type = 'http' as const;

	#url: string;
	#on_message: (data: any) => void;
	#headers: Record<string, string>;

	constructor(url: string, on_message: (data: any) => void) {
		this.#url = url;
		this.#on_message = on_message;
		this.#headers = {
			'Content-Type': 'application/json',
		};
	}

	async send(data: JSONRPCMessage): Promise<void> {
		try {
			const response = await fetch(this.#url, {
				method: 'POST',
				headers: this.#headers,
				body: JSON.stringify(data),
			});

			if (!response.ok) {
				throw new Error(`HTTP error: ${response.status}`);
			}

			const result = await response.json();
			this.#on_message(result);
		} catch (error) {
			console.error('Error sending HTTP request:', error);
			throw error;
		}
	}

	is_ready(): boolean {
		return true; // HTTP is always ready
	}

	get_type(): Api_Transport {
		return 'http';
	}
}
