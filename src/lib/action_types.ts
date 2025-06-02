import {z} from 'zod';

import {Action_Method} from '$lib/action_metatypes.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Jsonrpc_Notification, Jsonrpc_Request, Jsonrpc_Response_Or_Error} from '$lib/jsonrpc.js';

/**
 * Flag to indicate the phase of a request/response action.
 * - 'request': The action is being sent to the server
 * - 'response': The server has responded to the action
 * - null: The action is not a request/response type (e.g., local_call, remote_notification)
 */
export const Action_Request_Response_Flag = z.union([
	z.literal('request'),
	z.literal('response'),
	z.null(),
]);
export type Action_Request_Response_Flag = z.infer<typeof Action_Request_Response_Flag>;

export const Action_Kind = z.enum(['request_response', 'remote_notification', 'local_call']);
export type Action_Kind = z.infer<typeof Action_Kind>;

export const Action_Initiator = z.union([
	z.literal('client'),
	z.literal('server'),
	z.literal('both'),
]);
export type Action_Initiator = z.infer<typeof Action_Initiator>;

export const Action_Operation = z.union([z.literal('command'), z.literal('query')]);
export type Action_Operation = z.infer<typeof Action_Operation>;

// TODO temporary, maybe this can be a config object
export const Action_Auth = z.union([z.literal('public'), z.literal('authorize')]);
export type Action_Auth = z.infer<typeof Action_Auth>;

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
	kind: Action_Kind,
	request_response_flag: Action_Request_Response_Flag,
	// TODO BLOCK Action_Data probably
	jsonrpc_request: Jsonrpc_Request.optional(),
	jsonrpc_response: Jsonrpc_Response_Or_Error.optional(),
	jsonrpc_notification: Jsonrpc_Notification.optional(),
});
export type Action_Json = z.infer<typeof Action_Json>;
export type Action_Json_Input = z.input<typeof Action_Json>;
