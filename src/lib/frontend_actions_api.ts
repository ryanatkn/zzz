// @slop claude_opus_4

import type {Action_Method, Actions_Api} from '$lib/action_metatypes.js';
import type {Action_Event_Environment} from '$lib/action_event_types.js';
import {create_action_event} from '$lib/action_event.js';
import {is_jsonrpc_error_message} from '$lib/jsonrpc_helpers.js';
import type {
	Action_Spec,
	Local_Call_Action_Spec,
	Remote_Notification_Action_Spec,
	Request_Response_Action_Spec,
} from '$lib/action_spec.js';
import type {Action} from '$lib/action.svelte.js';
import {is_send_request, is_notification_send} from '$lib/action_event_helpers.js';

// TODO BLOCK @api think about unification with backend_actions_api.ts

/**
 * Interface for environments that support action history tracking.
 */
// TODO BLOCK @api refactor
interface Action_History_Environment extends Action_Event_Environment {
	actions: {
		add_json: (json: {method: Action_Method; action_event?: any}) => Action;
	};
}

/**
 * Creates the actions API methods for the given environment.
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
const create_action_method = (environment: Action_Event_Environment, spec: Action_Spec) => {
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

// TODO @api refactor
/**
 * Helper to track action in history if the environment supports it.
 */
const track_action = (
	environment: Action_Event_Environment,
	method: Action_Method,
	event: any,
): Action | undefined => {
	if (
		'actions' in environment &&
		typeof environment.actions === 'object' &&
		environment.actions &&
		'add_json' in environment.actions
	) {
		return (environment as Action_History_Environment).actions.add_json({
			method,
			action_event: event.toJSON(),
		});
	}
	return undefined;
};

/**
 * Helper to update tracked action with new event state.
 */
const update_tracked_action = (action: Action | undefined, event: any): void => {
	if (action && 'action_event' in action) {
		action.action_event = event;
	}
};

/**
 * Helper to extract result or throw error.
 */
const extract_result_or_throw = (event: any): any => {
	const data = event.data;

	if (data.step === 'handled') {
		return data.output;
	}

	if (data.step === 'failed' && data.error) {
		throw new Error(data.error.message);
	}

	// For void returns
	return undefined;
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
		const action = track_action(environment, spec.method, event);

		try {
			// Execute synchronously
			event.parse().handle_sync();

			update_tracked_action(action, event);
			return extract_result_or_throw(event);
		} catch (error) {
			update_tracked_action(action, event); // TODO @many track the error?
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
		const action = track_action(environment, spec.method, event);

		try {
			// Execute asynchronously
			await event.parse().handle_async();

			update_tracked_action(action, event);
			return extract_result_or_throw(event);
		} catch (error) {
			update_tracked_action(action, event); // TODO @many track the error?
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
		// Check if environment supports networking
		if (!('peer' in environment)) {
			console.log(`environment`, environment);
			throw new Error(
				`Environment does not support network communication for action '${spec.method}'`,
			);
		}

		const event = create_action_event(environment, spec, input);
		const action = track_action(environment, spec.method, event);

		try {
			// Parse and handle send_request phase
			await event.parse().handle_async();

			// Check if handled successfully and has request
			if (
				event.data.step === 'handled' &&
				// TODO BLOCK @api @many is this ever not the case?
				is_send_request(event.data)
			) {
				update_tracked_action(action, event);

				// Send the request and wait for response
				const response = await environment.peer.send(event.data.request);

				// Transition to receive_response phase
				event.transition('receive_response');

				// Set the response data
				event.set_response(response);

				// Parse and handle the response
				await event.parse().handle_async();
				update_tracked_action(action, event);

				// Extract the result
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
				update_tracked_action(action, event);
				return extract_result_or_throw(event);
			}
		} catch (error) {
			update_tracked_action(action, event); // TODO @many track the error?
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
		const action = track_action(environment, spec.method, event);

		try {
			// Parse and handle
			await event.parse().handle_async();
			update_tracked_action(action, event);

			// Send notification if successful and has notification
			if (
				event.data.step === 'handled' &&
				// TODO BLOCK @api @many is this ever not the case?
				is_notification_send(event.data)
			) {
				// Send without waiting for response
				await environment.peer.send(event.data.notification);
			}

			// Notifications return void
			return undefined as any;
		} catch (error) {
			update_tracked_action(action, event); // TODO @many track the error?
			throw error;
		}
	};
};
