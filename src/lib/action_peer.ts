// @slop claude_opus_4

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
import {create_action_event} from '$lib/action_event.js';
import type {Action_Method} from '$lib/action_metatypes.js';

// TODO the goal is to make this fully symmetric but we're not quite there

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
		const transport = this.transports.get_or_throw(
			options?.transport_name ?? this.default_send_options.transport_name,
		);
		return transport.send(message);
	}

	async receive(message: unknown): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		try {
			// Validate the message is a valid JSON-RPC message
			if (!message || typeof message !== 'object') {
				return this.#create_parse_error_response();
			}

			// Handle a single message - MCP does not support JSON-RPC batches
			// because of some tricky cases, so we don't either
			return await this.#process_message(message);
		} catch (error) {
			// Only programmer errors should reach here
			this.environment.log?.error('unexpected error:', error);
			return this.#create_fatal_error_response(message);
		}
	}

	/**
	 * Process a single JSON-RPC message.
	 */
	async #process_message(message: unknown): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		// Validate it's a request or notification
		if (is_jsonrpc_request(message)) {
			return this.#process_request(message);
		} else if (is_jsonrpc_notification(message)) {
			await this.#process_notification(message);
			return null; // Notifications don't have responses
		} else {
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
	 * Process a JSON-RPC request.
	 */
	async #process_request(request: Jsonrpc_Request): Promise<Jsonrpc_Message_From_Server_To_Client> {
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

			// Fallback error
			return create_jsonrpc_error_message(request.id, {
				code: JSONRPC_INTERNAL_ERROR,
				message: 'failed to process request',
			});
		} catch (error) {
			return create_jsonrpc_error_message_from_thrown(request.id, error);
		}
	}

	/**
	 * Process a JSON-RPC notification.
	 */
	async #process_notification(notification: Jsonrpc_Notification): Promise<void> {
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
			this.environment.log?.error(`error processing notification:`, error);
		}
	}

	/**
	 * Create error response for parse errors.
	 */
	#create_parse_error_response(): Jsonrpc_Message_From_Server_To_Client {
		return create_jsonrpc_error_message(null, {
			code: JSONRPC_PARSE_ERROR,
			message: 'parse error',
		});
	}

	/**
	 * Create error response for fatal/unexpected errors.
	 */
	#create_fatal_error_response(raw_message: unknown): Jsonrpc_Message_From_Server_To_Client | null {
		return create_jsonrpc_error_message(to_jsonrpc_message_id(raw_message), {
			code: JSONRPC_INTERNAL_ERROR,
			message: 'internal server error',
		});
	}
}
