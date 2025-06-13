import {z} from 'zod';

import {Action_Method} from '$lib/action_metatypes.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Jsonrpc_Params, Jsonrpc_Result} from '$lib/jsonrpc.js';

export const Action_Kind = z.enum(['request_response', 'remote_notification', 'local_call']);
export type Action_Kind = z.infer<typeof Action_Kind>;

// TODO extensible?
export const Action_Environment = z.enum(['frontend', 'backend']);
export type Action_Environment = z.infer<typeof Action_Environment>;

// TODO extend `Action_Environment` or is this more efficient/easier to work with?
export const Action_Initiator = z.enum(['frontend', 'backend', 'both']);
export type Action_Initiator = z.infer<typeof Action_Initiator>;

export const is_action_initiator = (v: unknown): v is Action_Initiator =>
	v === 'frontend' || v === 'backend' || v === 'both';

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

export const Action_Json = Cell_Json.extend({
	method: Action_Method,
	action_event: z.any().optional(), // TODO BLOCK type Frontend_Action_Event
});
export type Action_Json = z.infer<typeof Action_Json>;
export type Action_Json_Input = z.input<typeof Action_Json>;
