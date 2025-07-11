// @slop Claude Opus 4

import {z} from 'zod';

import type {
	Jsonrpc_Message_From_Client_To_Server,
	Jsonrpc_Message_From_Server_To_Client,
	Jsonrpc_Notification,
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
} from '$lib/jsonrpc.js';

// TODO figure out the symmetry of frontend and backend transports (none/partial/full?) --
// we may also need orthogonal abstractions to clarify the transport role

// TODO support configurable/extensible transports

export const Transport_Name = z.string(); // not branded for convenience, will just error at runtime, the schema is just for docs atm
export type Transport_Name = z.infer<typeof Transport_Name>;

export interface Transport {
	transport_name: Transport_Name;
	/* eslint-disable @typescript-eslint/method-signature-style */
	send(message: Jsonrpc_Request): Promise<Jsonrpc_Response_Or_Error>;
	send(message: Jsonrpc_Notification): Promise<null>;
	send(
		message: Jsonrpc_Message_From_Client_To_Server,
	): Promise<Jsonrpc_Message_From_Server_To_Client | null>;
	is_ready: () => boolean;
}

export class Transports {
	#current_transport: Transport | null = null;
	#transport_by_name: Map<Transport_Name, Transport> = new Map();

	/**
	 * Whether to allow fallback to other transports if the current one is not available.
	 * @default true
	 */
	allow_fallback: boolean = true; // TODO allow registering transports with a priority level so this can be customized

	/**
	 * Registers a transport.
	 */
	register_transport(transport: Transport): void {
		this.#transport_by_name.set(transport.transport_name, transport); // TODO maybe ensure unregistering of any previous transport?

		// Set current transport if not already set
		if (!this.#current_transport) {
			this.#current_transport = transport;
		}
	}

	set_current_transport(transport_name: Transport_Name): void {
		const transport = this.#transport_by_name.get(transport_name);
		if (!transport) throw new Error(`Transport not registered: ${transport_name}`);
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

	get_current_transport_name(): Transport_Name | null {
		return this.#current_transport?.transport_name ?? null;
	}

	get_transport(transport_name: Transport_Name): Transport | null {
		return this.#transport_by_name.get(transport_name) ?? null;
	}

	/**
	 * Gets either the current transport or the first ready transport
	 * depending on `allow_fallback`, or throws an error.
	 * @param transport_name Optional transport to use instead of the current
	 * @throws when no transport available or ready
	 */
	get_or_throw(transport_name?: Transport_Name): Transport {
		if (this.allow_fallback) {
			return this.#get_first_ready_or_throw(transport_name);
		}
		return this.#get_exact_or_throw(transport_name);
	}

	/**
	 * Gets the specified transport, defaulting to the current, or throws an error.
	 * @param transport_name Optional transport type to use instead of the current
	 * @throws when no transport available or ready
	 */
	#get_exact_or_throw(transport_name?: Transport_Name): Transport {
		const transport = transport_name
			? this.#transport_by_name.get(transport_name)
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
	 * @param transport_name Optional transport type or array of types to use instead of the current
	 * @throws when no transport available or ready
	 */
	#get_first_ready_or_throw(transport_name?: Transport_Name | Array<Transport_Name>): Transport {
		// First try the specified transport(s) if provided
		if (transport_name) {
			const transport_names = Array.isArray(transport_name) ? transport_name : [transport_name];

			for (const transport_name of transport_names) {
				const transport = this.#transport_by_name.get(transport_name);
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
		for (const transport of this.#transport_by_name.values()) {
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
