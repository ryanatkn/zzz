import type {Transport_Provider} from '$lib/api_client.js';
import {create_uuid} from '$lib/zod_helpers.js';
import type {Api_Transport} from '$lib/api.js';
import type {JSONRPCMessage} from '$lib/jsonrpc.js';

// TODO BLOCK tighten up this API

/**
 * JSON-RPC client tbat supports multiple transport methods and flexible usage.
 */
export class Jsonrpc_Client {
	#transport: Transport_Provider | null = null;
	#transports: Map<Api_Transport, Transport_Provider> = new Map();
	#default_transport: Api_Transport;

	constructor(default_transport: Api_Transport = 'http') {
		this.#default_transport = default_transport;
	}

	/**
	 * Registers a transport provider for a specific method.
	 */
	register_transport(method: Api_Transport, provider: Transport_Provider): void {
		this.#transports.set(method, provider);

		// If no transport is selected, use this one
		if (!this.#transport) {
			this.#transport = provider;
		}
	}

	/**
	 * Sets the active transport method.
	 */
	set_transport(method: Api_Transport): boolean {
		const transport = this.#transports.get(method);
		if (!transport) {
			return false;
		}
		this.#transport = transport;
		return true;
	}

	/**
	 * Checks if the client is ready to send messages.
	 */
	is_ready(): boolean {
		return !!this.#transport && this.#transport.is_ready();
	}

	/**
	 * Gets the current transport type.
	 */
	get_transport_type(): Api_Transport | null {
		return this.#transport ? this.#transport.get_type() : null;
	}

	/**
	 * Sends a JSON-RPC request.
	 */
	send(method: string, params: Record<string, any>, id?: string): void {
		if (!this.#transport || !this.#transport.is_ready()) {
			throw new Error('No transport available or transport not ready');
		}

		const message: JSONRPCMessage = {
			jsonrpc: '2.0',
			method,
			params,
			id: id || create_uuid(),
		};

		this.#transport.send(message);
	}

	/**
	 * Sends a JSON-RPC notification (no response expected).
	 */
	notify(method: string, params: Record<string, any>): void {
		if (!this.#transport || !this.#transport.is_ready()) {
			throw new Error('No transport available or transport not ready');
		}

		const message: JSONRPCMessage = {
			jsonrpc: '2.0',
			method,
			params,
		};

		this.#transport.send(message);
	}
}
