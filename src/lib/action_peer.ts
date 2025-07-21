// @slop Claude Opus 4

import {create_action_event} from '$lib/action_event.js';
import {
	JSONRPC_INTERNAL_ERROR,
	JSONRPC_INVALID_REQUEST,
	JSONRPC_METHOD_NOT_FOUND,
	JSONRPC_PARSE_ERROR,
	Jsonrpc_Message_From_Client_To_Server,
	Jsonrpc_Message_From_Server_To_Client,
	Jsonrpc_Notification,
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
} from '$lib/jsonrpc.js';
import {Transports, type Transport_Name} from '$lib/transports.js';
import type {Action_Event_Environment} from '$lib/action_event_types.js';
import {
	create_jsonrpc_error_message,
	create_jsonrpc_error_message_from_thrown,
	to_jsonrpc_message_id,
	is_jsonrpc_request,
	is_jsonrpc_notification,
} from '$lib/jsonrpc_helpers.js';
import type {Action_Method} from '$lib/action_metatypes.js';
import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';

// TODO @api @many refactor frontend_actions_api.ts with action_peer.ts

// TODO the goal is to make this fully symmetric but we're not quite there,
// this does receiving but only part of sending, and some deeper changes may be needed

export interface Action_Peer_Send_Options {
	transport_name?: Transport_Name;
}

export interface Action_Peer_Options {
	environment: Action_Event_Environment;

	// For sending - optional because some peers may be receive-only
	transports?: Transports;

	// Default send options
	default_send_options?: Partial<Action_Peer_Send_Options>;
}

export class Action_Peer {
	readonly environment: Action_Event_Environment;
	readonly transports: Transports;
	// TODO maybe could be refactored in the direction of `transports` being sending, so what's receiving?
	// It seems abstracting that out would make this class much simpler and generic, but too much so?
	// What deps should it actually know about, and what gains could we have by making it more decoupled?
	// e.g. don't just decouple for the sake of imagined flexibility!

	default_send_options: Action_Peer_Send_Options;

	constructor(options: Action_Peer_Options) {
		this.environment = options.environment;
		this.transports = options.transports ?? new Transports();
		this.default_send_options = options.default_send_options ?? {};
	}

	// TODO the transport type option here may be a bit too magic
	async send(
		message: Jsonrpc_Request,
		options?: Action_Peer_Send_Options,
	): Promise<Jsonrpc_Response_Or_Error>;
	async send(message: Jsonrpc_Notification, options?: Action_Peer_Send_Options): Promise<null>;
	async send(
		message: Jsonrpc_Message_From_Client_To_Server,
		options?: Action_Peer_Send_Options,
	): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		try {
			const transport = this.transports.get_ready_transport(
				options?.transport_name ?? this.default_send_options.transport_name,
			);

			if (!transport) {
				this.environment.log?.error('[action_peer.send] no transport available');
				// TODO BLOCK return a more specific JSON-RPC error
				return this.#create_fatal_error_response(message);
			}

			// TODO BLOCK clean up error handling, notice `receive` catches but we intentionally throw here, what should the peer be doing?
			// I think we should use return values here since
			// it's a high level abstraction in terms of the module architecture,
			// and is not called deep in user code,
			// and if this is the case then the transports should prefer returning errors over throwing
			const result = await transport.send(message);
			return result;
		} catch (error) {
			this.environment.log?.error('[action_peer.send] unexpected error:', error);
			return this.#create_fatal_error_response(message);
		} // TODO finally?
	}

	async receive(message: unknown): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		try {
			// TODO better validation? move to `#receive_message`?
			if (!message || typeof message !== 'object') {
				return this.#create_parse_error_response();
			}

			const result = await this.#receive_message(message);
			return result;
		} catch (error) {
			this.environment.log?.error('[action_peer.receive] unexpected error:', error);
			// TODO BLOCK refactor with the above, get error handling right
			return this.#create_fatal_error_response(message);
		} // TODO finally?
	}

	/**
	 * Process a single JSON-RPC message, returning a response message if any.
	 */
	async #receive_message(message: unknown): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		if (is_jsonrpc_request(message)) {
			return this.#receive_request(message);
		} else if (is_jsonrpc_notification(message)) {
			await this.#receive_notification(message);
			return null;
		} else {
			// TODO BLOCK error messages info is being lost here
			const id = to_jsonrpc_message_id(message);
			return id === null
				? null
				: create_jsonrpc_error_message(id, {
						code: JSONRPC_INVALID_REQUEST,
						message: 'invalid request',
					});
		}
	}

	/**
	 * Process a JSON-RPC request. Returns the response message.
	 */
	async #receive_request(request: Jsonrpc_Request): Promise<Jsonrpc_Message_From_Server_To_Client> {
		const spec = this.environment.lookup_action_spec(request.method as Action_Method); // TODO @many try not to cast, idk what the best design is here
		if (!spec) {
			return create_jsonrpc_error_message(request.id, {
				code: JSONRPC_METHOD_NOT_FOUND,
				message: `method not found: ${request.method}`,
			});
		}

		try {
			// Create action event in receive_request phase
			const event = create_action_event(this.environment, spec, request.params, 'receive_request');
			event.set_request(request);

			// Parse and handle
			await event.parse().handle_async();

			// Check if we successfully handled the request
			if (event.data.step === 'handled') {
				// Transition to send_response phase
				event.transition('send_response');
				await event.parse().handle_async();

				// TODO doesn't seem exactly right, shouldn't need the guard, or needs some other tweaks
				// Return the response if any
				if (event.data.response) {
					return event.data.response;
				}
			}

			// Check for errors
			if (event.data.step === 'failed') {
				return create_jsonrpc_error_message(request.id, event.data.error);
			}

			// TODO BLOCK refactor with error helpers (returning data should be the norm, maybe simple plain fns)
			// Fallback error
			return create_jsonrpc_error_message(request.id, {
				code: JSONRPC_INTERNAL_ERROR,
				message: 'failed to receive request',
			});
		} catch (error) {
			return create_jsonrpc_error_message_from_thrown(request.id, error);
		}
	}

	/**
	 * Process a JSON-RPC notification. Returns nothing, no response exists.
	 */
	async #receive_notification(notification: Jsonrpc_Notification): Promise<void> {
		const spec = this.environment.lookup_action_spec(notification.method as Action_Method); // TODO @many try not to cast, idk what the best design is here
		if (!spec) {
			this.environment.log?.warn(`unknown notification method: ${notification.method}`);
			return;
		}

		try {
			// Create action event in receive phase
			const event = create_action_event(this.environment, spec, notification.params, 'receive');
			event.set_notification(notification);

			// Parse and handle
			await event.parse().handle_async();

			if (event.data.step === 'failed') {
				this.environment.log?.error(`notification handler failed:`, event.data.error);
			}
		} catch (error) {
			this.environment.log?.error(`error receiving notification:`, error);
		}
	}

	// TODO BLOCK maybe delete/refactor
	#create_parse_error_response(): Jsonrpc_Message_From_Server_To_Client {
		return create_jsonrpc_error_message(null, {
			code: JSONRPC_PARSE_ERROR,
			message: 'parse error',
		});
	}

	// TODO BLOCK maybe delete/refactor
	#create_fatal_error_response(raw_message: unknown): Jsonrpc_Message_From_Server_To_Client | null {
		return create_jsonrpc_error_message(to_jsonrpc_message_id(raw_message), {
			code: JSONRPC_INTERNAL_ERROR,
			message: UNKNOWN_ERROR_MESSAGE,
		});
	}
}
