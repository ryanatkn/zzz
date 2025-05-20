import type {z} from 'zod';

import {Action_Message_Any, action_spec_by_method} from '$lib/action_collections.js';
import type {Action_Json} from '$lib/action_types.js';
import {Action_Message} from '$lib/action_messages.js';
import {Action_Message_Type, Action_Method} from '$lib/action_metatypes.js';

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

export const to_action_request_message_type = (method: Action_Method): Action_Message_Type =>
	Action_Message_Type.parse(method + '_request');

export const to_action_response_message_type = (method: Action_Method): Action_Message_Type =>
	Action_Message_Type.parse(method + '_response');
