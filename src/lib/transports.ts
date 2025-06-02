import {z} from 'zod';

import type {
	Jsonrpc_Batch_Request,
	Jsonrpc_Batch_Response,
	Jsonrpc_Message_From_Client_To_Server,
	Jsonrpc_Message_From_Server_To_Client,
	Jsonrpc_Notification,
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
} from '$lib/jsonrpc.js';
import type {Socket} from '$lib/socket.svelte.js';
import {Request_Tracker} from '$lib/request_tracker.svelte.js';
import {Jsonrpc_Error, jsonrpc_errors} from '$lib/jsonrpc_errors.js';

// TODO probably add reactivity?

// TODO support configurable/extensible transports
export const Transport_Type = z.enum(['http_rpc', 'websocket_rpc']);
export type Transport_Type = z.infer<typeof Transport_Type>;

export interface Transport {
	type: Transport_Type;
	/* eslint-disable @typescript-eslint/method-signature-style */
	send(message: Jsonrpc_Request): Promise<Jsonrpc_Response_Or_Error>;
	send(message: Jsonrpc_Notification): Promise<null>;
	send(message: Jsonrpc_Batch_Request): Promise<Jsonrpc_Batch_Response>;
	send(
		message: Jsonrpc_Message_From_Client_To_Server,
	): Promise<Jsonrpc_Message_From_Server_To_Client | null>;
	is_ready: () => boolean;
}

export class Transports {
	#current_transport: Transport | null = null;
	#transport_by_type: Map<Transport_Type, Transport> = new Map();

	/**
	 * Whether to allow fallback to other transports if the current one is not available.
	 * @default true
	 */
	allow_fallback: boolean = true; // TODO allow registering transports with a priority level so this can be customized

	/**
	 * Registers a transport.
	 */
	register_transport(transport: Transport): void {
		this.#transport_by_type.set(transport.type, transport);

		// Set current transport if not already set
		if (!this.#current_transport) {
			this.#current_transport = transport;
		}
	}

	set_current_transport(transport_type: Transport_Type): void {
		const transport = this.#transport_by_type.get(transport_type);
		if (!transport) throw new Error(`Transport not registered: ${transport_type}`);
		this.#current_transport = transport;
	}

	is_ready(): boolean | null {
		const transport = this.#current_transport;
		if (!transport) return null;
		return transport.is_ready();
	}

	get_current_transport(): Transport | null {
		return this.#current_transport ?? null;
	}

	get_current_transport_type(): Transport_Type | null {
		return this.#current_transport?.type ?? null;
	}

	get_transport(transport_type: Transport_Type): Transport | null {
		return this.#transport_by_type.get(transport_type) ?? null;
	}

	get_transport_type(): Transport_Type | null {
		return this.#current_transport?.type ?? null;
	}

	/**
	 * Gets either the current transport or the first ready transport
	 * depending on `allow_fallback`, or throws an error.
	 * @param transport_type Optional transport type to use instead of the current
	 * @throws when no transport available or ready
	 */
	get_or_throw(transport_type?: Transport_Type): Transport {
		if (this.allow_fallback) {
			return this.#get_first_ready_or_throw(transport_type);
		}
		return this.#get_exact_or_throw(transport_type);
	}

	/**
	 * Gets the specified transport, defaulting to the current, or throws an error.
	 * @param transport_type Optional transport type to use instead of the current
	 * @throws when no transport available or ready
	 */
	#get_exact_or_throw(transport_type?: Transport_Type): Transport {
		const transport = transport_type
			? this.#transport_by_type.get(transport_type)
			: this.#current_transport;

		if (!transport) {
			throw new Error('No transport available');
		}
		if (!transport.is_ready()) {
			throw new Error('Transport not ready');
		}

		return transport;
	}

	/**
	 * Gets the appropriate transport or throws an error.
	 * @param transport_type Optional transport type or array of types to use instead of the current
	 * @throws when no transport available or ready
	 */
	#get_first_ready_or_throw(transport_type?: Transport_Type | Array<Transport_Type>): Transport {
		// First try the specified transport(s) if provided
		if (transport_type) {
			const transport_types = Array.isArray(transport_type) ? transport_type : [transport_type];

			for (const transport_type of transport_types) {
				const transport = this.#transport_by_type.get(transport_type);
				if (transport?.is_ready()) {
					return transport;
				}
			}
		}

		// Then try the current transport if it's ready
		if (this.#current_transport?.is_ready()) {
			return this.#current_transport;
		}

		// Finally, try any other available transport
		for (const transport of this.#transport_by_type.values()) {
			if (transport.is_ready()) {
				return transport;
			}
		}

		// No ready transport found, throw an error
		if (!this.#current_transport) {
			throw new Error('No transport available');
		}
		throw new Error('Transport not ready');
	}
}

/**
 * WebSocket transport provider that uses the Socket class.
 */
export class Websocket_Rpc_Transport implements Transport {
	readonly type = 'websocket_rpc' as const;

	#socket: Socket;
	#request_tracker: Request_Tracker;

	constructor(socket: Socket, request_timeout_ms?: number) {
		this.#socket = socket;
		this.#request_tracker = new Request_Tracker(request_timeout_ms);

		// Set up the message handler
		socket.onmessage = (event) => {
			try {
				const data = JSON.parse(event.data);
				this.#request_tracker.handle_message(data);
			} catch (error) {
				console.error('[websocket transport] Error parsing WebSocket message:', error);
			}
		};
	}

	async send(message: Jsonrpc_Request): Promise<Jsonrpc_Response_Or_Error>;
	async send(message: Jsonrpc_Notification): Promise<null>;
	async send(message: Jsonrpc_Batch_Request): Promise<Jsonrpc_Batch_Response>;
	async send(
		message: Jsonrpc_Message_From_Client_To_Server,
	): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		console.log(`[websocket transport] data`, message);
		if (!this.is_ready()) {
			throw jsonrpc_errors.service_unavailable_error('WebSocket not connected');
		}

		try {
			// If this is a JSON-RPC request with an id (not a notification),
			// set up request tracking.
			// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
			if ('id' in message && message.id != null) {
				// TODO track the whole request?
				const deferred = this.#request_tracker.track_request(message.id);
				this.#socket.send(message);

				// Return the promise that will resolve when the response is received
				const result = await deferred.promise;
				console.log(`result`, message, result);
				return result;
			} else {
				// For notifications, just send without tracking
				// TODO if we want retries at this abstraction level we'll need to add a way to track them
				this.#socket.send(message);
				return null;
			}
		} catch (error) {
			console.error('[websocket transport] Error sending message:', error);
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

/**
 * HTTP transport provider for RPC API calls.
 */
export class Http_Rpc_Transport implements Transport {
	readonly type = 'http_rpc' as const;

	#url: string;
	#headers: Record<string, string>;

	constructor(url: string, headers?: Record<string, string>) {
		this.#url = url;
		this.#headers = headers ?? {'content-type': 'application/json', accept: 'application/json'};
	}

	async send(message: Jsonrpc_Request): Promise<Jsonrpc_Response_Or_Error>;
	async send(message: Jsonrpc_Notification): Promise<null>;
	async send(message: Jsonrpc_Batch_Request): Promise<Jsonrpc_Batch_Response>;
	async send(
		message: Jsonrpc_Message_From_Client_To_Server,
	): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		console.log(`[http transport] message`, message);
		try {
			const response = await fetch(this.#url, {
				method: 'POST', // TODO support GET
				headers: this.#headers,
				body: JSON.stringify(message),
				// TODO
				// signal: AbortSignal.timeout(REQUEST_TIMEOUT),
			});

			const result = await response.json();
			console.log(`send result`, result);

			// For JSON-RPC, we always expect a 200 OK response
			// The actual error will be in the JSON-RPC error field
			if (!response.ok) {
				throw jsonrpc_errors.internal_error(
					`HTTP error: ${response.status} ${response.statusText}`,
				);
			}

			console.log(`[http transport] result`, result);
			return result;
		} catch (error) {
			console.error('[http transport] Error sending HTTP request:', error);
			if (error instanceof Jsonrpc_Error) {
				throw error;
			}
			throw jsonrpc_errors.internal_error('Error sending HTTP request', {
				error: error instanceof Error ? error.message : String(error),
			});
		}
	}

	is_ready(): boolean {
		// TODO maybe have this connected to a stateful connection check?
		// or maybe not -- this allows us to always fall back to trying http_rpc
		return true;
	}
}
