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
	#current_provider: Api_Transport_Provider | null = null;
	#provider_by_transport: Map<Api_Transport, Api_Transport_Provider> = new Map();

	/**
	 * Sends a JSON-RPC request.
	 */
	send(
		method: JSONRPCMethod,
		params: JSONRPCRequestParams | undefined,
		id: JSONRPCRequestId = create_uuid(),
		transport?: Api_Transport,
	): void {
		const provider = this.#get_transport_or_throw(transport);

		const message: JSONRPCRequest = {
			jsonrpc: '2.0',
			id,
			method,
		};
		if (params !== undefined) {
			message.params = params;
		}

		provider.send(message);
	}

	/**
	 * Sends a JSON-RPC notification (no response expected).
	 */
	notify(
		method: JSONRPCMethod,
		params: JSONRPCNotificationParams | undefined,
		transport?: Api_Transport,
	): void {
		const provider = this.#get_transport_or_throw(transport);

		const message: JSONRPCNotification = {
			jsonrpc: '2.0',
			method,
		};
		if (params !== undefined) {
			message.params = params;
		}

		provider.send(message);
	}

	/**
	 * Gets the appropriate transport or throws an error.
	 * @param transport Optional transport type to use instead of the current
	 * @throws when no transport available or ready
	 */
	#get_transport_or_throw(transport?: Api_Transport): Api_Transport_Provider {
		const provider = transport
			? this.#provider_by_transport.get(transport)
			: this.#current_provider;

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
		this.#provider_by_transport.set(transport, provider);

		// Set current transport if not already set
		if (!this.#current_provider) {
			this.#current_provider = provider;
		}
	}

	get_current_transport(): Api_Transport_Provider | null {
		return this.#current_provider ?? null;
	}

	set_current_transport(transport: Api_Transport): boolean {
		const provider = this.#provider_by_transport.get(transport);
		if (!provider) {
			return false;
		}
		this.#current_provider = provider;
		return true;
	}

	is_ready(): boolean | null {
		const provider = this.#current_provider;
		if (!provider) return null;
		return provider.is_ready();
	}

	get_transport(transport: Api_Transport): Api_Transport_Provider | null {
		return this.#provider_by_transport.get(transport) ?? null;
	}

	get_transport_type(): Api_Transport | null {
		return this.#current_provider?.type ?? null;
	}
}
