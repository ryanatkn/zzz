import {z} from 'zod';

import {JsonrpcParams, JsonrpcResult} from './jsonrpc.js';

export const ActionKind = z.enum(['request_response', 'remote_notification', 'local_call']);
export type ActionKind = z.infer<typeof ActionKind>;

// TODO extensible?
export const ActionExecutor = z.enum(['frontend', 'backend']);
export type ActionExecutor = z.infer<typeof ActionExecutor>;

// TODO extend `ActionExecutor` or is this more efficient/easier to work with?
// TODO is `ActionResponder` needed? `ActionParticipant`?
// maybe only `ActionParticipant` to handle both sides
export const ActionInitiator = z.enum(['frontend', 'backend', 'both']);
export type ActionInitiator = z.infer<typeof ActionInitiator>;

// TODO maybe just use `ActionInitiator` directly?
export const is_action_initiator = (v: unknown): v is ActionInitiator =>
	v === 'frontend' || v === 'backend' || v === 'both';

// TODO temporary/stubbed, maybe this can be a config object
/** @stub */
export const ActionAuth = z.union([z.literal('public'), z.literal('authorize')]);
export type ActionAuth = z.infer<typeof ActionAuth>;

// TODO support a config object when we have the use cases,
// maybe support `false` as a value, possibly instead of `null`?
// idk I like `null` as the base for things like this
// and allowing duplicate values seems less than ideal, but maybe is better overall
export const ActionSideEffects = z.union([z.literal(true), z.null()]);
export type ActionSideEffects = z.infer<typeof ActionSideEffects>;

export const ActionInput = z.union([JsonrpcParams, z.undefined(), z.void()]);
export type ActionInput = z.infer<typeof ActionInput>;

export const ActionOutput = z.union([JsonrpcResult, z.undefined(), z.void()]);
export type ActionOutput = z.infer<typeof ActionOutput>;
