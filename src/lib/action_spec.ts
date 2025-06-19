// @slop claude_opus_4

import {z} from 'zod';

import {Action_Method} from '$lib/action_metatypes.js';
import {
	Action_Auth,
	Action_Initiator,
	Action_Kind,
	Action_Side_Effects,
} from '$lib/action_types.js';

export const Action_Spec_Base = z.object({
	method: Action_Method,
	kind: Action_Kind,
	initiator: Action_Initiator,
	auth: Action_Auth.nullable(),
	// TODO @api stubbed out and not yet used, should be for GET/POST distinction and other things, we get guarantees like cacheability from these, interesting with transport agnosticism
	side_effects: Action_Side_Effects,
	input: z.union([z.instanceof(z.ZodObject), z.instanceof(z.ZodNull), z.instanceof(z.ZodOptional)]),
	output: z.union([
		z.instanceof(z.ZodObject),
		z.instanceof(z.ZodNull),
		z.instanceof(z.ZodOptional<z.ZodVoid>),
	]),
	async: z.boolean(),
});
export type Action_Spec_Base = z.infer<typeof Action_Spec_Base>;

/** Type for request_response actions (bidirectional request/response pattern). */
export const Request_Response_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('request_response').default('request_response'),
	auth: Action_Auth,
	async: z.literal(true).default(true),
});
export type Request_Response_Action_Spec = z.infer<typeof Request_Response_Action_Spec>;

/** Type for remote_notification actions (unidirectional fire-and-forget messages). */
export const Remote_Notification_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('remote_notification').default('remote_notification'),
	auth: z.null().default(null),
	side_effects: z.literal(true).nullable().default(true), // TODO this probably will change hence the awkward types
	output: z.instanceof(z.ZodVoid),
	async: z.literal(true).default(true),
});
export type Remote_Notification_Action_Spec = z.infer<typeof Remote_Notification_Action_Spec>;

/** Type for local_call actions (in-process operations that never cross boundaries). */
export const Local_Call_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('local_call').default('local_call'),
	auth: z.null().default(null),
});
export type Local_Call_Action_Spec = z.infer<typeof Local_Call_Action_Spec>;

export const Action_Spec = z.union([
	Request_Response_Action_Spec,
	Remote_Notification_Action_Spec,
	Local_Call_Action_Spec,
]);
export type Action_Spec = z.infer<typeof Action_Spec>;

/**
 * Type guard to validate if a value is an Action_Spec
 */
export const is_action_spec = (value: unknown): value is Action_Spec => {
	return (
		value !== null &&
		typeof value === 'object' &&
		'method' in value &&
		'kind' in value &&
		((value as Action_Spec).kind === 'request_response' ||
			(value as Action_Spec).kind === 'remote_notification' ||
			(value as Action_Spec).kind === 'local_call')
	);
};

export const collect_action_specs = (obj: Record<string, Action_Spec>): Array<Action_Spec> => {
	const specs: Array<Action_Spec> = [];

	for (const value of Object.values(obj)) {
		if (is_action_spec(value)) {
			specs.push(value);
		}
	}

	return specs;
};
