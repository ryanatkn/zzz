import type {
	JSONRPCMethod,
	JSONRPCNotification,
	JSONRPCNotificationParams,
	JSONRPCRequest,
	JSONRPCRequestId,
	JSONRPCRequestParams,
} from '$lib/jsonrpc.js';
import {create_uuid} from '$lib/zod_helpers.js';
import type {Api_Transport_Type, Api_Transport} from '$lib/api.js';

/**
 * JSON-RPC client that supports multiple transports with flexible usage.
 */
export class Jsonrpc_Client {
	#current_transport: Api_Transport | null = null;
	#transport_by_type: Map<Api_Transport_Type, Api_Transport> = new Map();

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
		transport_type?: Api_Transport_Type,
	): void {
		console.log(`send`, method, params, id);
		const transport = this.#get_or_throw(transport_type);

		const message: JSONRPCRequest = {
			jsonrpc: '2.0',
			id,
			method,
		};
		if (params !== undefined) {
			message.params = params;
		}

		transport.send(message);
	}

	/**
	 * Sends a JSON-RPC notification (no response expected).
	 */
	notify(
		method: JSONRPCMethod,
		params: JSONRPCNotificationParams | void,
		transport_type?: Api_Transport_Type,
	): void {
		console.log(`notify`, method, params);
		const transport = this.#get_or_throw(transport_type);

		const message: JSONRPCNotification = {
			jsonrpc: '2.0',
			method,
		};
		if (params !== undefined) {
			message.params = params;
		}

		transport.send(message);
	}

	/**
	 * Registers a transport.
	 */
	register_transport(transport: Api_Transport): void {
		this.#transport_by_type.set(transport.type, transport);

		// Set current transport if not already set
		if (!this.#current_transport) {
			this.#current_transport = transport;
		}
	}

	set_current_transport(transport_type: Api_Transport_Type): void {
		const transport = this.#transport_by_type.get(transport_type);
		if (!transport) throw Error(`Transport not registered: ${transport_type}`);
		this.#current_transport = transport;
	}

	is_ready(): boolean | null {
		const transport = this.#current_transport;
		if (!transport) return null;
		return transport.is_ready();
	}

	get_current_transport(): Api_Transport | null {
		return this.#current_transport ?? null;
	}

	get_current_transport_type(): Api_Transport_Type | null {
		return this.#current_transport?.type ?? null;
	}

	get_transport(transport_type: Api_Transport_Type): Api_Transport | null {
		return this.#transport_by_type.get(transport_type) ?? null;
	}

	get_transport_type(): Api_Transport_Type | null {
		return this.#current_transport?.type ?? null;
	}

	/**
	 * Gets either the current transport or the first ready transport
	 * depending on `allow_fallback`, or throws an error.
	 * @param transport_type Optional transport type to use instead of the current
	 * @throws when no transport available or ready
	 */
	#get_or_throw(transport_type?: Api_Transport_Type): Api_Transport {
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
	#get_exact_or_throw(transport_type?: Api_Transport_Type): Api_Transport {
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
	#get_first_ready_or_throw(
		transport_type?: Api_Transport_Type | Array<Api_Transport_Type>,
	): Api_Transport {
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
