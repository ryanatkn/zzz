import {z} from 'zod';

import type {JSONRPCMessage} from '$lib/jsonrpc.js';
import type {Socket} from '$lib/socket.svelte.js';
import type {Api_Result} from '$lib/api.js';

// TODO support configurable/extensible transports
export const Transport_Type = z.enum(['http_rpc', 'websocket_rpc']);
export type Transport_Type = z.infer<typeof Transport_Type>;

export interface Transport {
	type: Transport_Type;
	send: (data: JSONRPCMessage) => Promise<Api_Result>;
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
		if (!transport) throw Error(`Transport not registered: ${transport_type}`);
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

	async send(data: JSONRPCMessage): Promise<Api_Result> {
		if (!this.is_ready()) {
			throw new Error('WebSocket not connected');
		}
		this.#socket.send(data);
		// TODO BLOCK probably do the request tracking here, except for notifications
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
	#on_message: (data: any) => void;
	#headers: Record<string, string>;

	constructor(url: string, on_message: (data: any) => void, headers?: Record<string, string>) {
		this.#url = url;
		this.#on_message = on_message;
		this.#headers = headers ?? {'content-type': 'application/json', accept: 'application/json'};
	}

	async send(data: JSONRPCMessage): Promise<Api_Result> {
		try {
			const response = await fetch(this.#url, {
				method: 'POST', // TODO support GET
				headers: this.#headers,
				body: JSON.stringify(data),
				// TODO
				// signal: AbortSignal.timeout(REQUEST_TIMEOUT),
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
		// TODO maybe have this connected to a stateful connection check?
		// or maybe not -- this allows us to always fall back to trying http_rpc
		return true;
	}
}
