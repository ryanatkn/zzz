// @slop Claude Opus 4

import {z} from 'zod';

import {ActionMethod} from './action_metatypes.js';
import {ActionAuth, ActionInitiator, ActionKind, ActionSideEffects} from './action_types.js';

export const ActionSpec = z.strictObject({
	method: ActionMethod,
	kind: ActionKind,
	initiator: ActionInitiator,
	auth: ActionAuth.nullable(),
	// TODO @api should be for GET/POST distinction and probably other things, we get guarantees like cacheability from these, interesting with transport agnosticism
	side_effects: ActionSideEffects,
	input: z.union([
		z.custom<z.ZodObject<any>>((v) => v instanceof z.ZodObject),
		z.custom<z.ZodNull>((v) => v instanceof z.ZodNull),
		z.custom<z.ZodOptional<any>>((v) => v instanceof z.ZodOptional),
	]),
	output: z.union([
		z.custom<z.ZodObject<any>>((v) => v instanceof z.ZodObject),
		z.custom<z.ZodNull>((v) => v instanceof z.ZodNull),
		z.custom<z.ZodOptional<any>>((v) => v instanceof z.ZodOptional),
		z.custom<z.ZodUnion<any>>((v) => v instanceof z.ZodUnion),
	]),
	async: z.boolean(),
});
export type ActionSpec = z.infer<typeof ActionSpec>;

export const RequestResponseActionSpec = ActionSpec.extend({
	kind: z.literal('request_response').default('request_response'),
	auth: ActionAuth,
	async: z.literal(true).default(true),
});
export type RequestResponseActionSpec = z.infer<typeof RequestResponseActionSpec>;

export const RemoteNotificationActionSpec = ActionSpec.extend({
	kind: z.literal('remote_notification').default('remote_notification'),
	auth: z.null().default(null),
	side_effects: z.literal(true).nullable().default(true), // TODO this probably will change hence the awkward types
	output: z.custom<z.ZodVoid>((v) => v instanceof z.ZodVoid),
	async: z.literal(true).default(true),
});
export type RemoteNotificationActionSpec = z.infer<typeof RemoteNotificationActionSpec>;

/**
 * Local calls can wrap synchronous or asynchronous actions,
 * and are the escape hatch for remote APIs that do not support SAES.
 */
export const LocalCallActionSpec = ActionSpec.extend({
	kind: z.literal('local_call').default('local_call'),
	auth: z.null().default(null),
});
export type LocalCallActionSpec = z.infer<typeof LocalCallActionSpec>;

export const ActionSpecUnion = z.union([
	RequestResponseActionSpec,
	RemoteNotificationActionSpec,
	LocalCallActionSpec,
]);
export type ActionSpecUnion = z.infer<typeof ActionSpecUnion>;

export const is_action_spec = (value: unknown): value is ActionSpecUnion =>
	value !== null &&
	typeof value === 'object' &&
	'method' in value &&
	'kind' in value &&
	(value.kind as string) in ActionKind.def.entries;
