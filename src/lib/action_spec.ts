// @slop claude_opus_4

import {z} from 'zod';

import {Action_Method} from '$lib/action_metatypes.js';
import {
	Action_Auth,
	Action_Initiator,
	Action_Kind,
	Action_Side_Effects,
} from '$lib/action_types.js';

export const Action_Spec = z.object({
	method: Action_Method,
	kind: Action_Kind,
	initiator: Action_Initiator,
	auth: Action_Auth.nullable(),
	// TODO @api should be for GET/POST distinction and probably other things, we get guarantees like cacheability from these, interesting with transport agnosticism
	side_effects: Action_Side_Effects,
	input: z.union([z.instanceof(z.ZodObject), z.instanceof(z.ZodNull), z.instanceof(z.ZodOptional)]),
	output: z.union([
		z.instanceof(z.ZodObject),
		z.instanceof(z.ZodNull),
		z.instanceof(z.ZodOptional<z.ZodVoid>),
		// TODO broken type and schema usage, idk what I'm doing
		z.instanceof(z.ZodUnion),
	]),
	async: z.boolean(),
}); // TODO also make strict? additional properties are not passed through
export type Action_Spec = z.infer<typeof Action_Spec>;

export const Request_Response_Action_Spec = Action_Spec.extend({
	kind: z.literal('request_response').default('request_response'),
	auth: Action_Auth,
	async: z.literal(true).default(true),
});
export type Request_Response_Action_Spec = z.infer<typeof Request_Response_Action_Spec>;

export const Remote_Notification_Action_Spec = Action_Spec.extend({
	kind: z.literal('remote_notification').default('remote_notification'),
	auth: z.null().default(null),
	side_effects: z.literal(true).nullable().default(true), // TODO this probably will change hence the awkward types
	output: z.instanceof(z.ZodVoid),
	async: z.literal(true).default(true),
});
export type Remote_Notification_Action_Spec = z.infer<typeof Remote_Notification_Action_Spec>;

/**
 * Local calls can wrap synchronous or asynchronous actions,
 * and are the escape hatch for remote APIs that do not support SAES.
 */
export const Local_Call_Action_Spec = Action_Spec.extend({
	kind: z.literal('local_call').default('local_call'),
	auth: z.null().default(null),
});
export type Local_Call_Action_Spec = z.infer<typeof Local_Call_Action_Spec>;

export const Action_Spec_Union = z.union([
	Request_Response_Action_Spec,
	Remote_Notification_Action_Spec,
	Local_Call_Action_Spec,
]);
export type Action_Spec_Union = z.infer<typeof Action_Spec_Union>;

export const is_action_spec = (value: unknown): value is Action_Spec_Union =>
	value !== null &&
	typeof value === 'object' &&
	'method' in value &&
	'kind' in value &&
	Action_Kind._def.values.includes(value.kind as any);
