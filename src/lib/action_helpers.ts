import type {z} from 'zod';

import {
	Action_Message_Any,
	action_spec_by_method,
	type Action_Message_From_Client,
	type Action_Message_From_Server,
} from '$lib/action_collections.js';
import type {Action_Json} from '$lib/action_types.js';
import {Action_Message, type Action_Message_Name} from '$lib/action_messages.js';
import type {Action_Method} from '$lib/action_metatypes.js';

// Constants for preview length and formatting
export const ACTION_DATE_FORMAT = 'MMM d, p';
export const ACTION_TIME_FORMAT = 'p';

// Helper function to convert an action to its json representation
export const create_action_json = (
	action: Action_Message_From_Client | Action_Message_From_Server,
): Action_Json | null => {
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
): z.ZodType<Action_Message_Any> | undefined => {
	const key = to_action_request_message_name(method);
	return key && (Action_Message[key] as any);
};

// TODO some hacky types but looks correct
export const lookup_response_action_schema = (
	method: Action_Method,
): z.ZodType<Action_Message_Any> | undefined => {
	const key = to_action_response_message_name(method);
	return key && (Action_Message[key] as any);
};

export const to_action_request_message_name = (
	method: Action_Method,
): Action_Message_Name | undefined => {
	// TODO BLOCK validate it's a request/response action
	const name = method + '_request';
	return name in Action_Message ? (name as Action_Message_Name) : undefined;
};

export const to_action_response_message_name = (
	method: Action_Method,
): Action_Message_Name | undefined => {
	// TODO BLOCK validate it's a request/response action
	const name = method + '_response';
	return name in Action_Message ? (name as Action_Message_Name) : undefined;
};
