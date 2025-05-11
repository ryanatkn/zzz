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
		transport_type?: Api_Transport,
	): void {
		const transport = this.#get_transport_or_throw(transport_type);

		const message: JSONRPCNotification = {
			jsonrpc: '2.0',
			method,
			params,
		};

		transport.send(message);
	}

	/**
	 * Gets the appropriate transport or throws an error.
	 * @param transport_type Optional transport type to use instead of the current
	 * @throws when no transport available or ready
	 */
	#get_transport_or_throw(transport_type?: Api_Transport): Api_Transport_Provider {
		const transport = transport_type ? this.#transports.get(transport_type) : this.#transport;

		if (!transport) {
			throw new Error('No transport available');
		}
		if (!transport.is_ready()) {
			throw new Error('Transport not ready');
		}

		return transport;
	}

	/**
	 * Registers a transport provider for a specific method.
	 */
	register_transport(method: Api_Transport, provider: Api_Transport_Provider): void {
		this.#transports.set(method, provider);

		// Set current transport if not already set
		if (!this.#transport) {
			this.#transport = provider;
		}
	}

	/**
	 * Sets the current transport method.
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
		return !!this.#transport?.is_ready();
	}

	/**
	 * Gets the current transport, if any.
	 */
	get_current_transport(): Api_Transport_Provider | null {
		return this.#transport ?? null;
	}

	/**
	 * Gets the current transport type, if any.
	 */
	get_transport_type(): Api_Transport | null {
		return this.#transport?.type ?? null;
	}
}
