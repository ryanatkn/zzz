import type {z} from 'zod';

import {Action_Message_Union} from '$lib/action_collections.js';
import type {Action_Auth} from '$lib/action_types.js';
import {Action_Messages} from '$lib/action_messages.js';
import {
	Action_Message_Type,
	Action_Method,
	type Action_Message_Params,
} from '$lib/action_metatypes.js';
import type {Jsonrpc_Request_Id, Jsonrpc_Singular_Message} from '$lib/jsonrpc.js';
import {to_jsonrpc_message_id} from '$lib/jsonrpc_helpers.js';

// TODO BLOCK @api refactor all of this, is all very messy

export const ACTION_DATE_FORMAT = 'MMM d, p';
export const ACTION_TIME_FORMAT = 'p';

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

// TODO BLOCK @api delete
export const to_action_message_type = (
	method: Action_Method,
	request_response_flag: 'request' | 'response' | null,
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

// TODO @api rethink these
/**
 * Convert an action name to its type name.
 */
export const to_action_spec_identifier = (method: Action_Method): string => `${method}_action_spec`;

/**
 * Convert an action name to its params type name.
 */
export const to_action_spec_input_identifier = (method: Action_Method): string =>
	`${to_action_spec_identifier(method)}.input`;

/**
 * Convert an action name to its response schema identifier.
 */
export const to_action_spec_output_identifier = (method: Action_Method): string =>
	`${to_action_spec_identifier(method)}.output`;

export const to_action_spec_auth_identifier = (auth: Action_Auth): string =>
	auth === 'public' ? 'Public_Server_Action_Handler' : 'Authorized_Server_Action_Handler';
