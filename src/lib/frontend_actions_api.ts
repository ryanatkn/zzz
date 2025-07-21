// @slop Claude Opus 4

import type {Action_Method, Actions_Api} from '$lib/action_metatypes.js';
import type {Action_Event_Environment} from '$lib/action_event_types.js';
import {Action_Event, create_action_event} from '$lib/action_event.js';
import type {
	Action_Spec_Union,
	Local_Call_Action_Spec,
	Remote_Notification_Action_Spec,
	Request_Response_Action_Spec,
} from '$lib/action_spec.js';
import {is_send_request, is_notification_send} from '$lib/action_event_helpers.js';

// TODO @api @many refactor frontend_actions_api.ts with action_peer.ts

// TODO @api think about unification between frontend|backend_actions_api.ts

/**
 * Creates the actions API methods for the frontend.
 * Uses a Proxy to provide dynamic method lookup with full type safety.
 */
export const create_frontend_actions_api = <T extends Action_Event_Environment>(
	environment: T,
): Actions_Api => {
	return new Proxy({} as Actions_Api, {
		get(_target, method: string) {
			const spec = environment.lookup_action_spec(method as Action_Method);
			if (!spec) {
				return undefined;
			}

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

// TODO BLOCK thrown jsonrpc error type?
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
			action_event_data: event.toJSON(),
		});
		action?.listen_to_action_event(event);

		event.parse().handle_sync();

		return extract_result_or_throw(event);
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
			action_event_data: event.toJSON(),
		});
		action?.listen_to_action_event(event);

		await event.parse().handle_async();

		return extract_result_or_throw(event);
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
			action_event_data: event.toJSON(),
		});
		action?.listen_to_action_event(event);

		await event.parse().handle_async();

		if (!is_send_request(event.data)) throw Error(); // TODO @many maybe make this an assertion helper?

		if (event.data.step !== 'handled') {
			return extract_result_or_throw(event);
		}

		const response = await environment.peer.send(event.data.request);

		event.transition('receive_response');

		// TODO @api shouldn't this happen in the peer like the other method calls?
		event.set_response(response);

		await event.parse().handle_async();

		return extract_result_or_throw(event);
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
		const event = create_action_event(environment, spec, input);
		const action = environment.actions?.add_from_json({
			method: spec.method,
			action_event_data: event.toJSON(),
		});
		action?.listen_to_action_event(event);

		await event.parse().handle_async();

		if (!is_notification_send(event.data)) throw Error(); // TODO @many maybe make this an assertion helper?

		if (event.data.step === 'handled') {
			const result = await environment.peer.send(event.data.notification);
			// Check if notification failed to send
			if (result !== null) {
				environment.log?.error('notification send failed:', result.error);
			}
			// TODO @api rethink this with the action event lifecycle, should there be more after this?
		}
	};
};
