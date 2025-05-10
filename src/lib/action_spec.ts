import {z} from 'zod';

import {Uuid_With_Default, Datetime_Now, Type_Literal} from '$lib/zod_helpers.js';
import type {Http_Method} from '$lib/api.js';
import {Action_Method} from '$lib/action_metatypes.js';

/**
 * Centralized definitions for core action structures.
 * This module defines the core types and structures for the action system.
 */

/**
 * Base schema for all actions with common properties.
 *
 * Similar to `Cell` but omits `updated` because they're typically immutable.
 */
export const Action_Message_Base = z
	.object({
		id: Uuid_With_Default, // TODO this means we're trusting client ids, revisit
		created: Datetime_Now,
		method: Action_Method,
	})
	.passthrough(); // TODO is this a good/safe pattern for base schemas? we're doing this so we can parse loosely sometimes, but see too how the Uuid has a fallback
export type Action_Message_Base = z.infer<typeof Action_Message_Base>;

export const Action_Kind = z.enum(['request_response', 'server_notification', 'client_local']);
export type Action_Kind = z.infer<typeof Action_Kind>;

export const Action_Spec_Base = z.object({
	method: Action_Method,
	params: z.instanceof(z.ZodType),
	kind: Action_Kind,
});
export type Action_Spec_Base = z.infer<typeof Action_Spec_Base>;

// Type for request_response actions (client requests, server responds)
export const Request_Response_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('request_response').default('request_response'),
	http_method: z.custom<Http_Method>(),
	auth: z.union([z.literal('authenticate'), z.literal('authorize'), z.null()]),
	/**
	 * For the request_response the base action `params` are the request params,
	 * and we mirror the name here for the response message payload.
	 */
	response_params: z.instanceof(z.ZodType),
});
export type Request_Response_Action_Spec = z.infer<typeof Request_Response_Action_Spec>;

// Type for server_notification actions (server sends without a request)
export const Server_Notification_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('server_notification').default('server_notification'),
});
export type Server_Notification_Action_Spec = z.infer<typeof Server_Notification_Action_Spec>;

// Type for client_local actions (that never leave the client)
export const Client_Local_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('client_local').default('client_local'),
	/**
	 * This needs to be watched closely, so the friction from the branded type is desired.
	 */
	returns: Type_Literal,
});
export type Client_Local_Action_Spec = z.infer<typeof Client_Local_Action_Spec>;

// Union of all action spec types
export const Action_Spec = z.union([
	Request_Response_Action_Spec,
	Server_Notification_Action_Spec,
	Client_Local_Action_Spec,
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
			(value as Action_Spec).kind === 'server_notification' ||
			(value as Action_Spec).kind === 'client_local')
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
