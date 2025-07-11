import {z} from 'zod';

import {Jsonrpc_Params, Jsonrpc_Result} from '$lib/jsonrpc.js';

export const Action_Kind = z.enum(['request_response', 'remote_notification', 'local_call']);
export type Action_Kind = z.infer<typeof Action_Kind>;

// TODO extensible?
export const Action_Executor = z.enum(['frontend', 'backend']);
export type Action_Executor = z.infer<typeof Action_Executor>;

// TODO extend `Action_Executor` or is this more efficient/easier to work with?
export const Action_Initiator = z.enum(['frontend', 'backend', 'both']);
export type Action_Initiator = z.infer<typeof Action_Initiator>;

// TODO maybe just use `Action_Initiator` directly?
export const is_action_initiator = (v: unknown): v is Action_Initiator =>
	v === 'frontend' || v === 'backend' || v === 'both';

// TODO temporary/stubbed, maybe this can be a config object
/** @stub */
export const Action_Auth = z.union([z.literal('public'), z.literal('authorize')]);
export type Action_Auth = z.infer<typeof Action_Auth>;

// TODO support a config object when we have the use cases,
// maybe support `false` as a value, possibly instead of `null`?
// idk I like `null` as the base for things like this
// and allowing duplicate values seems less than ideal, but maybe is better overall
export const Action_Side_Effects = z.union([z.literal(true), z.null()]);
export type Action_Side_Effects = z.infer<typeof Action_Side_Effects>;

export const Action_Input = z.union([Jsonrpc_Params, z.undefined(), z.void()]);
export type Action_Input = z.infer<typeof Action_Input>;

export const Action_Output = z.union([Jsonrpc_Result, z.undefined(), z.void()]);
export type Action_Output = z.infer<typeof Action_Output>;
