import type {z} from 'zod';

import {Action_Message_Union, action_spec_by_method} from '$lib/action_collections.js';
import {Action_Message_Base, type Action_Json} from '$lib/action_types.js';
import {Action_Messages} from '$lib/action_messages.js';
import {
	Action_Message_Type,
	Action_Method,
	type Action_Message_Params,
} from '$lib/action_metatypes.js';
import type {Api_Request_Response_Flag} from '$lib/api.js';
import type {
	Jsonrpc_Notification,
	Jsonrpc_Request,
	Jsonrpc_Request_Id,
	Jsonrpc_Singular_Message,
} from '$lib/jsonrpc.js';
import {to_jsonrpc_message_id} from '$lib/jsonrpc_helpers.js';
import type {Request_Response_Action_Spec_Auth} from '$lib/action_spec.js';

// Constants for preview length and formatting
export const ACTION_DATE_FORMAT = 'MMM d, p';
export const ACTION_TIME_FORMAT = 'p';

// Helper function to convert an action to its json representation
export const create_action_json = (action: Action_Message_Union): Action_Json | null => {
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
): z.ZodType<Action_Message_Union> | undefined =>
	Action_Messages[to_action_request_message_type(method)] as any;

// TODO some hacky types but looks correct
export const lookup_response_action_schema = (
	method: Action_Method,
): z.ZodType<Action_Message_Union> | undefined =>
	Action_Messages[to_action_response_message_type(method)] as any;

// TODO maybe variant(s) or replace with send/receive? server/client?
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
	jsonrpc_message_or_id: Jsonrpc_Request_Id | Jsonrpc_Singular_Message | null,
): Action_Message_Union =>
	Action_Messages[action_message_type].parse({
		params,
		jsonrpc_message_id: to_jsonrpc_message_id(jsonrpc_message_or_id),
	});

export const to_action_message_identifier = (message_type: Action_Message_Type): string =>
	`Action_Messages['${message_type}']`; // TODO maybe have a non-type variant using `.` notation?

export const to_action_request_message_type = (method: Action_Method): Action_Message_Type =>
	Action_Message_Type.parse(method + '_request');

export const to_action_response_message_type = (method: Action_Method): Action_Message_Type =>
	Action_Message_Type.parse(method + '_response');

export const jsonrpc_request_to_action_message = (
	message: Jsonrpc_Request | Jsonrpc_Notification,
): Action_Message_Base =>
	Action_Message_Base.parse({
		type: to_action_message_type(Action_Method.parse(message.method), 'request'),
		method: message.method,
		jsonrpc_message_id: to_jsonrpc_message_id(message),
		params: message.params,
	});

// TODO @api rethink these
/**
 * Convert an action name to its type name.
 */
export const to_action_spec_identifier = (method: Action_Method): string => `${method}_action_spec`;

/**
 * Convert an action name to its params type name.
 */
export const to_action_spec_params_identifier = (method: Action_Method): string =>
	`${to_action_spec_identifier(method)}.params`;

/**
 * Convert an action name to its response schema identifier.
 */
export const to_action_spec_result_identifier = (method: Action_Method): string =>
	`${to_action_spec_identifier(method)}.result`;

export const to_action_spec_auth_identifier = (auth: Request_Response_Action_Spec_Auth): string =>
	auth === 'public'
		? 'Public_Server_Action_Handler'
		: auth === 'authenticate'
			? 'Authenticated_Server_Action_Handler'
			: 'Authorized_Server_Action_Handler';
