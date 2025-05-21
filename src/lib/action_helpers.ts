import type {z} from 'zod';

import {Action_Message_Any, action_spec_by_method} from '$lib/action_collections.js';
import type {Action_Json} from '$lib/action_types.js';
import {Action_Message} from '$lib/action_messages.js';
import {
	Action_Message_Type,
	Action_Method,
	type Action_Message_Params,
} from '$lib/action_metatypes.js';
import type {Api_Request_Response_Flag} from '$lib/api.js';
import type {JSONRPCNotification, JSONRPCRequest} from '$lib/jsonrpc.js';

// Constants for preview length and formatting
export const ACTION_DATE_FORMAT = 'MMM d, p';
export const ACTION_TIME_FORMAT = 'p';

// Helper function to convert an action to its json representation
export const create_action_json = (action: Action_Message_Any): Action_Json | null => {
	const spec = action_spec_by_method.get(action.method);
	if (!spec) {
		console.error(`No action spec found for method: ${action.method}`, action);
		return null;
	}
	return {
		...action,
		kind: spec.kind,
		updated: action.created,
	};
};

// TODO some hacky types but looks correct
export const lookup_request_action_schema = (
	method: Action_Method,
): z.ZodType<Action_Message_Any> | undefined =>
	Action_Message[to_action_request_message_type(method)] as any;

// TODO some hacky types but looks correct
export const lookup_response_action_schema = (
	method: Action_Method,
): z.ZodType<Action_Message_Any> | undefined =>
	Action_Message[to_action_response_message_type(method)] as any;

export const to_action_message_type = (
	method: Action_Method,
	request_response_flag: Api_Request_Response_Flag,
): Action_Message_Type =>
	Action_Message_Type.parse(
		request_response_flag === 'request'
			? to_action_request_message_type(method)
			: request_response_flag === 'response'
				? to_action_response_message_type(method)
				: method,
	);

export const to_action_message = <T extends Action_Message_Type>(
	action_message_type: T,
	params: Action_Message_Params[T],
	jsonrpc_message: JSONRPCRequest | JSONRPCNotification | null, // TODO maybe store this on the action message?
): Action_Message_Any =>
	Action_Message[action_message_type].parse({
		// Actions copy the jsonrpc id if available -- they're just different representations
		// of the same thing in different contexts
		id: jsonrpc_message && 'id' in jsonrpc_message ? jsonrpc_message.id : undefined,
		params,
	});

export const to_action_request_message_type = (method: Action_Method): Action_Message_Type =>
	Action_Message_Type.parse(method + '_request');

export const to_action_response_message_type = (method: Action_Method): Action_Message_Type =>
	Action_Message_Type.parse(method + '_response');
