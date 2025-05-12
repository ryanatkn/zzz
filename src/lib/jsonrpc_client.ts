import type {Api_Transport_Provider} from '$lib/api_client.js';
import {create_uuid} from '$lib/zod_helpers.js';
import type {Api_Transport} from '$lib/api.js';
import type {
	JSONRPCMethod,
	JSONRPCNotification,
	JSONRPCNotificationParams,
	JSONRPCRequest,
	JSONRPCRequestId,
	JSONRPCRequestParams,
} from '$lib/jsonrpc.js';

/**
 * JSON-RPC client tbat supports multiple transports with flexible usage.
 */
export class Jsonrpc_Client {
	#transport: Api_Transport_Provider | null = null;
	#transports: Map<Api_Transport, Api_Transport_Provider> = new Map();

	/**
	 * Sends a JSON-RPC request.
	 */
	send(
		method: JSONRPCMethod,
		params: JSONRPCRequestParams,
		id?: JSONRPCRequestId,
		transport_type?: Api_Transport,
	): void {
		const transport = this.#get_transport_or_throw(transport_type);

		const message: JSONRPCRequest = {
			jsonrpc: '2.0',
			id: id ?? create_uuid(),
			method,
			params,
		};

		transport.send(message);
	}

	/**
	 * Sends a JSON-RPC notification (no response expected).
	 */
	notify(
		method: JSONRPCMethod,
		params: JSONRPCNotificationParams,
		transport?: Api_Transport,
	): void {
		const provider = this.#get_transport_or_throw(transport);

		const message: JSONRPCNotification = {
			jsonrpc: '2.0',
			method,
			params,
		};

		provider.send(message);
	}

	/**
	 * Gets the appropriate transport or throws an error.
	 * @param transport Optional transport type to use instead of the current
	 * @throws when no transport available or ready
	 */
	#get_transport_or_throw(transport?: Api_Transport): Api_Transport_Provider {
		const provider = transport ? this.#transports.get(transport) : this.#transport;

		if (!provider) {
			throw new Error('No transport available');
		}
		if (!provider.is_ready()) {
			throw new Error('Transport not ready');
		}

		return provider;
	}

	/**
	 * Registers a provider for a specific transport.
	 */
	register_transport(transport: Api_Transport, provider: Api_Transport_Provider): void {
		this.#transports.set(transport, provider);

		// Set current transport if not already set
		if (!this.#transport) {
			this.#transport = provider;
		}
	}

	get_current_transport(): Api_Transport_Provider | null {
		return this.#transport ?? null;
	}

	set_current_transport(transport: Api_Transport): boolean {
		const provider = this.#transports.get(transport);
		if (!provider) {
			return false;
		}
		this.#transport = provider;
		return true;
	}

	is_ready(): boolean | null {
		const provider = this.#transport;
		if (!provider) return null;
		return provider.is_ready();
	}

	get_transport(transport: Api_Transport): Api_Transport_Provider | null {
		return this.#transports.get(transport) ?? null;
	}

	get_transport_type(): Api_Transport | null {
		return this.#transport?.type ?? null;
	}
}
