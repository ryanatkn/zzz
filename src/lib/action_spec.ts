import {z} from 'zod';

import {Type_Literal} from '$lib/zod_helpers.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {Action_Auth, Action_Initiator, Action_Kind, Action_Operation} from '$lib/action_types.js';

export const Action_Spec_Base = z.object({
	method: Action_Method,
	kind: Action_Kind,
	// TODO BLOCK @api is not yet used
	initiator: Action_Initiator,
	// TODO BLOCK @api is not yet used, should be for GET/POST distinction
	operation: Action_Operation.nullable(),
	auth: Action_Auth.nullable(),
	input: z.instanceof(z.ZodType),
	output: z.instanceof(z.ZodType).nullable(),
	// TODO BLOCK @api is not yet used
	async: z.boolean(),
});
export type Action_Spec_Base = z.infer<typeof Action_Spec_Base>;

/** Type for request_response actions (client requests, server responds). */
export const Request_Response_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('request_response').default('request_response'),
	operation: Action_Operation,
	auth: Action_Auth,
	output: z.instanceof(z.ZodType),
	async: z.literal(true).default(true),
});
export type Request_Response_Action_Spec = z.infer<typeof Request_Response_Action_Spec>;

/** Type for remote_notification actions (server sends without a request). */
export const Remote_Notification_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('remote_notification').default('remote_notification'),
	/**
	 * Remote notifications do not have an operation -
	 * they're saying "something happened" rather than "do this" or "get that".
	 */
	operation: z.null().default(null),
	auth: z.null().default(null),
	output: z.null().default(null),
	async: z.literal(false).default(false),
});
export type Remote_Notification_Action_Spec = z.infer<typeof Remote_Notification_Action_Spec>;

/** Type for local_call actions (that never leave the client). */
export const Local_Call_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('local_call').default('local_call'),
	auth: z.null().default(null),
	output: z.instanceof(z.ZodType),
	returns: Type_Literal, // TODO ideally wouldn't exist, should be generated from the zod schema
});
export type Local_Call_Action_Spec = z.infer<typeof Local_Call_Action_Spec>;

// Union of all action spec types
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

export const collect_action_specs_by_method = (
	obj: Record<string, Action_Spec>,
): Array<Action_Spec> => {
	const specs: Array<Action_Spec> = [];

	// Filter module exports for action specs
	for (const value of Object.values(obj)) {
		if (is_action_spec(value)) {
			specs.push(value);
		}
	}

	return specs;
};
