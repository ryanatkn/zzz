import type {
	JSONRPCMethod,
	JSONRPCNotification,
	JSONRPCNotificationParams,
	JSONRPCRequest,
	JSONRPCRequestId,
	JSONRPCRequestParams,
} from '$lib/jsonrpc.js';
import {create_uuid} from '$lib/zod_helpers.js';
import type {Api_Transport, Api_Transport_Provider} from '$lib/api.js';

/**
 * JSON-RPC client that supports multiple transports with flexible usage.
 */
export class Jsonrpc_Client {
	#current_provider: Api_Transport_Provider | null = null;
	#provider_by_transport: Map<Api_Transport, Api_Transport_Provider> = new Map();

	/**
	 * Whether to allow fallback to other transports if the current one is not available.
	 * @default true
	 */
	allow_fallback: boolean = true; // TODO allow registering transports with a priority level so this can be customized

	/**
	 * Sends a JSON-RPC request.
	 */
	send(
		method: JSONRPCMethod,
		params: JSONRPCRequestParams | void,
		id: JSONRPCRequestId = create_uuid(),
		transport?: Api_Transport,
	): void {
		console.log(`send`, method, params, id);
		const provider = this.#get_or_throw(transport);

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
		params: JSONRPCNotificationParams | void,
		transport?: Api_Transport,
	): void {
		console.log(`notify`, method, params);
		const provider = this.#get_or_throw(transport);

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
	 * Registers a provider for a specific transport.
	 */
	register_transport(transport: Api_Transport, provider: Api_Transport_Provider): void {
		this.#provider_by_transport.set(transport, provider);

		// Set current transport if not already set
		if (!this.#current_provider) {
			this.#current_provider = provider;
		}
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

	get_current_transport_provider(): Api_Transport_Provider | null {
		return this.#current_provider ?? null;
	}

	get_current_transport(): Api_Transport | null {
		return this.#current_provider?.type ?? null;
	}

	get_transport(transport: Api_Transport): Api_Transport_Provider | null {
		return this.#provider_by_transport.get(transport) ?? null;
	}

	get_transport_type(): Api_Transport | null {
		return this.#current_provider?.type ?? null;
	}

	/**
	 * Gets the specified transport provider, defaulting to the current, or throws an error.
	 * @param transport Optional transport type to use instead of the current
	 * @throws when no transport available or ready
	 */
	#get_or_throw(transport?: Api_Transport): Api_Transport_Provider {
		if (this.allow_fallback) {
			return this.#get_first_ready_or_throw(transport);
		}
		return this.#get_exact_or_throw(transport);
	}

	/**
	 * Gets the specified transport provider, defaulting to the current, or throws an error.
	 * @param transport Optional transport type to use instead of the current
	 * @throws when no transport available or ready
	 */
	#get_exact_or_throw(transport?: Api_Transport): Api_Transport_Provider {
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
	 * Gets the appropriate transport or throws an error.
	 * @param transport Optional transport type to use instead of the current
	 * @throws when no transport available or ready
	 */
	#get_first_ready_or_throw(
		transport?: Api_Transport | Array<Api_Transport>,
	): Api_Transport_Provider {
		// First try the specified transport(s) if provided
		if (transport) {
			const transports = Array.isArray(transport) ? transport : [transport];

			for (const t of transports) {
				const provider = this.#provider_by_transport.get(t);
				if (provider?.is_ready()) {
					return provider;
				}
			}
		}

		// Then try the current provider if it's ready
		if (this.#current_provider?.is_ready()) {
			return this.#current_provider;
		}

		// Finally, try any other available provider
		for (const provider of this.#provider_by_transport.values()) {
			if (provider.is_ready()) {
				return provider;
			}
		}

		// No ready provider found, throw an error
		if (!this.#current_provider) {
			throw new Error('No transport available');
		}
		throw new Error('Transport not ready');
	}
}
