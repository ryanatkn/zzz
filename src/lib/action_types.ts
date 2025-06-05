import {z} from 'zod';

import {Action_Method} from '$lib/action_metatypes.js';
import {Cell_Json} from '$lib/cell_types.js';
import {
	Jsonrpc_Notification,
	Jsonrpc_Params,
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
	Jsonrpc_Result,
} from '$lib/jsonrpc.js';

export const Action_Kind = z.enum(['request_response', 'remote_notification', 'local_call']);
export type Action_Kind = z.infer<typeof Action_Kind>;

export const Action_Initiator = z.union([
	z.literal('client'),
	z.literal('server'),
	z.literal('both'),
]);
export type Action_Initiator = z.infer<typeof Action_Initiator>;

// TODO temporary/stubbed, maybe this can be a config object
/** @stub */
export const Action_Auth = z.union([z.literal('public'), z.literal('authorize')]);
export type Action_Auth = z.infer<typeof Action_Auth>;

// TODO support a config object when we have the use cases
export const Action_Side_Effects = z.union([z.literal(true), z.null()]);
export type Action_Side_Effects = z.infer<typeof Action_Side_Effects>;

export const Action_Phase = z.enum([
	'send_request',
	'receive_request',
	'send_response',
	'receive_response',
	'send',
	'receive',
	'execute',
]);
export type Action_Phase = z.infer<typeof Action_Phase>;

export const ACTION_KIND_PHASES = {
	request_response: ['send_request', 'receive_request', 'send_response', 'receive_response'],
	remote_notification: ['send', 'receive'],
	local_call: ['execute'],
} as const satisfies Record<Action_Kind, ReadonlyArray<Action_Phase>>;

// TODO @api @many type - any should be any json I think, do with zod 4 for recursive type support
export const Action_Input = z.union([Jsonrpc_Params, z.any(), z.undefined(), z.void()]);
export type Action_Input = z.infer<typeof Action_Input>;

// TODO @api @many type - any should be any json I think, do with zod 4 for recursive type support
export const Action_Output = z.union([Jsonrpc_Result, z.any(), z.undefined(), z.void()]);
export type Action_Output = z.infer<typeof Action_Output>;

/**
 * Gets the appropriate handler phases for a method based on its action spec.
 */
export type Handler_Phases_For_Method<T_Method extends Action_Method> =
	T_Method extends keyof typeof ACTION_KIND_PHASES
		? (typeof ACTION_KIND_PHASES)[T_Method][number]
		: never;

// TODO maybe this for better type safety
// export const Action_Request_Response_Data = z.object({
//  kind: z.literal('request_response'),
// 	jsonrpc_request: Jsonrpc_Request,
// 	jsonrpc_response: Jsonrpc_Response_Or_Error,
// });
// export type Action_Request_Response_Data = z.infer<typeof Action_Request_Response_Data>;

// export const Action_Remote_Notification_Data = z.object({
// 	kind: z.literal('remote_notification'),
// 	jsonrpc_message: Jsonrpc_Request,
// });
// export type Action_Remote_Notification_Data = z.infer<typeof Action_Remote_Notification_Data>;

// export const Action_Local_Call_Data = z.object({
// 	kind: z.literal('local_call'),
// 	params: Jsonrpc_Params, // TODO BLOCK or should this be a message, so have a local transport for executing?
// });
// export type Action_Local_Call_Data = z.infer<typeof Action_Local_Call_Data>;

// export const Action_Data = z.union([
// 	Action_Request_Response_Data,
// 	Action_Remote_Notification_Data,
// 	Action_Local_Call_Data,
// ]);
// export type Action_Data = z.infer<typeof Action_Data>;

export const Action_Json = Cell_Json.extend({
	method: Action_Method,
	// TODO BLOCK Action_Data probably
	jsonrpc_request: Jsonrpc_Request.optional(),
	jsonrpc_response: Jsonrpc_Response_Or_Error.optional(),
	jsonrpc_notification: Jsonrpc_Notification.optional(),
});
export type Action_Json = z.infer<typeof Action_Json>;
export type Action_Json_Input = z.input<typeof Action_Json>;
