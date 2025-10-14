// @slop Claude Opus 4

import {create_action_event} from '$lib/action_event.js';
import {
	Jsonrpc_Message_From_Client_To_Server,
	Jsonrpc_Message_From_Server_To_Client,
	Jsonrpc_Notification,
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
	Jsonrpc_Error_Message,
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
import {jsonrpc_error_messages} from '$lib/jsonrpc_errors.js';
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
	// TODO maybe expand the pattern of using `transports` in send, so what's used in receive?
	// It seems abstracting that out would make this class much simpler and generic, but too much so?
	// What deps should it actually know about, and what gains could we have by making it more decoupled?
	// e.g. don't just decouple for the sake of imagined flexibility!

	default_send_options: Action_Peer_Send_Options;

	constructor(options: Action_Peer_Options) {
		this.environment = options.environment;
		this.transports = options.transports ?? new Transports();
		this.default_send_options = options.default_send_options ?? {};
	}

	// TODO the transport type option here may be bad magic
	async send(
		message: Jsonrpc_Request,
		options?: Action_Peer_Send_Options,
	): Promise<Jsonrpc_Response_Or_Error>;
	async send(
		message: Jsonrpc_Notification,
		options?: Action_Peer_Send_Options,
	): Promise<Jsonrpc_Error_Message | null>;
	async send(
		message: Jsonrpc_Message_From_Client_To_Server,
		options?: Action_Peer_Send_Options,
	): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		try {
			const transport = this.transports.get_transport(
				options?.transport_name ?? this.default_send_options.transport_name,
			);

			if (!transport) {
				this.environment.log?.error('[peer] send failed: no transport available');
				return create_jsonrpc_error_message(
					to_jsonrpc_message_id(message),
					jsonrpc_error_messages.service_unavailable('no transport available'),
				);
			}

			const message_type = is_jsonrpc_request(message) ? 'request' : 'notification';
			this.environment.log?.debug(
				`[peer] send ${message_type}:`,
				message.method,
				`via ${transport.transport_name}`,
			);

			const result = await transport.send(message);

			if (result && 'error' in result) {
				this.environment.log?.error(
					`[peer] send ${message_type} failed:`,
					message.method,
					result.error.message,
				);
			}

			return result;
		} catch (error) {
			// TODO add retry handling here?
			this.environment.log?.error('[peer] send unexpected error:', error);
			return create_jsonrpc_error_message_from_thrown(to_jsonrpc_message_id(message), error);
		} // TODO finally?
	}

	async receive(message: unknown): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		try {
			const result = await this.#receive_message(message);
			return result;
		} catch (error) {
			this.environment.log?.error('[peer] receive unexpected error:', error);
			// Return appropriate error response based on the message
			return create_jsonrpc_error_message_from_thrown(to_jsonrpc_message_id(message), error);
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
			return create_jsonrpc_error_message(
				to_jsonrpc_message_id(message),
				jsonrpc_error_messages.invalid_request(),
			);
		}
	}

	/**
	 * Process a JSON-RPC request. Returns the response message.
	 */
	async #receive_request(request: Jsonrpc_Request): Promise<Jsonrpc_Message_From_Server_To_Client> {
		const spec = this.environment.lookup_action_spec(request.method as Action_Method); // TODO @many try not to cast, idk what the best design is here
		if (!spec) {
			this.environment.log?.warn(`[peer] receive request: method not found:`, request.method);
			return create_jsonrpc_error_message(
				request.id,
				jsonrpc_error_messages.method_not_found(request.method),
			);
		}

		this.environment.log?.debug(`[peer] receive request:`, request.method);

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

			// Check for terminal failure
			if (event.data.step === 'failed') {
				this.environment.log?.error(
					`[peer] receive request failed:`,
					request.method,
					event.data.error,
				);
				return create_jsonrpc_error_message(request.id, event.data.error);
			}

			// Check if transitioned to error phase (send_error)
			if (event.data.phase === 'send_error') {
				// Error handler may exist - try to handle it (already parsed)
				await event.handle_async();

				// Return error response (handler may have modified/logged it)
				return create_jsonrpc_error_message(request.id, event.data.error);
			}

			// Fallback for unexpected states
			this.environment.log?.error(
				`[peer] receive request: unexpected state:`,
				request.method,
				event.data,
			);
			return create_jsonrpc_error_message(
				request.id,
				jsonrpc_error_messages.internal_error(UNKNOWN_ERROR_MESSAGE),
			);
		} catch (error) {
			this.environment.log?.error(`[peer] receive request exception:`, request.method, error);
			return create_jsonrpc_error_message_from_thrown(request.id, error);
		}
	}

	/**
	 * Process a JSON-RPC notification. Returns nothing, no response exists.
	 */
	async #receive_notification(notification: Jsonrpc_Notification): Promise<void> {
		const spec = this.environment.lookup_action_spec(notification.method as Action_Method); // TODO @many try not to cast, idk what the best design is here
		if (!spec) {
			this.environment.log?.warn(
				`[peer] receive notification: method not found:`,
				notification.method,
			);
			return;
		}

		this.environment.log?.debug(`[peer] receive notification:`, notification.method);

		try {
			// Create action event in receive phase
			const event = create_action_event(this.environment, spec, notification.params, 'receive');
			event.set_notification(notification);

			// Parse and handle
			await event.parse().handle_async();

			if (event.data.step === 'failed') {
				this.environment.log?.error(
					`[peer] receive notification failed:`,
					notification.method,
					event.data.error,
				);
			}
		} catch (error) {
			this.environment.log?.error(
				`[peer] receive notification exception:`,
				notification.method,
				error,
			);
		}
	}
}
