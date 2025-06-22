// @slop claude_opus_4

import type {Action_Method, Actions_Api} from '$lib/action_metatypes.js';
import type {Action_Event_Environment} from '$lib/action_event_types.js';
import {Action_Event, create_action_event} from '$lib/action_event.js';
import {is_jsonrpc_error_message} from '$lib/jsonrpc_helpers.js';
import type {
	Action_Spec_Union,
	Local_Call_Action_Spec,
	Remote_Notification_Action_Spec,
	Request_Response_Action_Spec,
} from '$lib/action_spec.js';
import {is_send_request, is_notification_send} from '$lib/action_event_helpers.js';

// TODO BLOCK @api streaming

// TODO @api think about unification between frontend|backend_actions_api.ts

/**
 * Creates the actions API methods for the frontend.
 * Uses a Proxy to provide dynamic method lookup with full type safety.
 */
export const create_frontend_actions_api = <T extends Action_Event_Environment>(
	environment: T,
): Actions_Api => {
	// Create a proxy that dynamically creates methods based on the action specs
	return new Proxy({} as Actions_Api, {
		get(_target, method: string) {
			// Check if this is a valid action method
			const spec = environment.lookup_action_spec(method as Action_Method);
			if (!spec) {
				return undefined;
			}

			// Return the appropriate method implementation
			return create_action_method(environment, spec);
		},
		has(_target, method: string) {
			return environment.lookup_action_spec(method as Action_Method) !== undefined;
		},
	});
};

/**
 * Creates a method that executes an action through its complete lifecycle.
 */
const create_action_method = (environment: Action_Event_Environment, spec: Action_Spec_Union) => {
	// Return different implementations based on action kind
	switch (spec.kind) {
		case 'local_call':
			return spec.async
				? create_async_local_call_method(environment, spec)
				: create_sync_local_call_method(environment, spec);
		case 'request_response':
			return create_request_response_method(environment, spec);
		case 'remote_notification':
			return create_remote_notification_method(environment, spec);
	}
};

// TODO maybe move this?
const extract_result_or_throw = (event: Action_Event): any => {
	const {data} = event;

	if (data.step === 'handled') {
		return data.output;
	}

	if (data.step === 'failed') {
		throw new Error(data.error.message);
	}

	throw new Error(); // TODO maybe include a message? is an internal failure
};

/**
 * Creates a synchronous local call method.
 */
const create_sync_local_call_method = (
	environment: Action_Event_Environment,
	spec: Local_Call_Action_Spec,
) => {
	return (input?: unknown) => {
		const event = create_action_event(environment, spec, input);
		const action = environment.actions?.add_from_json({
			method: spec.method,
			action_event: event.toJSON(),
		});

		try {
			// Execute synchronously
			event.parse().handle_sync();

			action?.update_from_event(event);
			return extract_result_or_throw(event);
		} catch (error) {
			action?.update_from_event(event); // TODO @many track the error?
			throw error;
		}
	};
};

/**
 * Creates an asynchronous local call method.
 */
const create_async_local_call_method = (
	environment: Action_Event_Environment,
	spec: Local_Call_Action_Spec,
) => {
	return async (input?: unknown) => {
		const event = create_action_event(environment, spec, input);
		const action = environment.actions?.add_from_json({
			method: spec.method,
			action_event: event.toJSON(),
		});

		try {
			// Execute asynchronously
			await event.parse().handle_async();

			action?.update_from_event(event);
			return extract_result_or_throw(event);
		} catch (error) {
			action?.update_from_event(event); // TODO @many track the error?
			throw error;
		}
	};
};

/**
 * Creates a request/response method that communicates over the network.
 */
const create_request_response_method = (
	environment: Action_Event_Environment,
	spec: Request_Response_Action_Spec,
) => {
	return async (input?: unknown) => {
		const event = create_action_event(environment, spec, input);
		const action = environment.actions?.add_from_json({
			method: spec.method,
			action_event: event.toJSON(),
		});

		try {
			// Parse and handle send_request phase
			await event.parse().handle_async();

			// Check if handled successfully and has request
			if (!is_send_request(event.data)) throw Error(); // TODO @many maybe make this an assertion helper?
			if (event.data.step === 'handled') {
				action?.update_from_event(event);

				// Send the request and wait for response
				const response = await environment.peer.send(event.data.request);

				// Transition to receive_response phase
				event.transition('receive_response');

				// Set the response data
				event.set_response(response);

				// Parse and handle the response
				await event.parse().handle_async();
				action?.update_from_event(event);

				// Extract the result
				// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
				if (event.data.step === 'handled') {
					return event.data.output;
				}

				// Handle error responses
				if (is_jsonrpc_error_message(response)) {
					throw new Error(response.error.message);
				}

				throw new Error('No output received');
			} else {
				// Failed to handle send_request
				action?.update_from_event(event);
				return extract_result_or_throw(event);
			}
		} catch (error) {
			action?.update_from_event(event); // TODO @many track the error?
			throw error;
		}
	};
};

/**
 * Creates a remote notification method (fire and forget).
 */
const create_remote_notification_method = (
	environment: Action_Event_Environment,
	spec: Remote_Notification_Action_Spec,
) => {
	return async (input?: unknown) => {
		// Check if environment supports networking
		if (!('peer' in environment)) {
			throw new Error(
				`Environment does not support network communication for action '${spec.method}'`,
			);
		}

		const event = create_action_event(environment, spec, input);
		const action = environment.actions?.add_from_json({
			method: spec.method,
			action_event: event.toJSON(),
		});

		try {
			// Parse and handle
			await event.parse().handle_async();
			action?.update_from_event(event);

			if (!is_notification_send(event.data)) throw Error(); // TODO @many maybe make this an assertion helper?

			// Send notification if successful
			if (event.data.step === 'handled') {
				await environment.peer.send(event.data.notification);
			}
		} catch (error) {
			action?.update_from_event(event); // TODO @many track the error?
			throw error;
		}
	};
};
