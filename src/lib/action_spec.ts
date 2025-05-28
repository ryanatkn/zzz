import {z} from 'zod';

import {Type_Literal} from '$lib/zod_helpers.js';
import type {Http_Method} from '$lib/api.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {Action_Kind} from '$lib/action_types.js';

export const Action_Spec_Base = z.object({
	method: Action_Method,
	params: z.instanceof(z.ZodType),
	kind: Action_Kind,
});
export type Action_Spec_Base = z.infer<typeof Action_Spec_Base>;

export const Request_Response_Action_Spec_Auth = z.union([
	z.literal('public'),
	z.literal('authenticate'),
	z.literal('authorize'),
]);
export type Request_Response_Action_Spec_Auth = z.infer<typeof Request_Response_Action_Spec_Auth>;

// Type for request_response actions (client requests, server responds)
export const Request_Response_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('request_response').default('request_response'),
	// TODO BLOCK @api rethink this, maybe just read/write or query/command separation via a flag?
	http_method: z.custom<Http_Method>(),
	auth: Request_Response_Action_Spec_Auth,
	/**
	 * For the request_response the base action `params` are the request params,
	 * and we mirror the name here for the response message payload.
	 */
	result: z.instanceof(z.ZodType),
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
	returns: Type_Literal, // TODO BLOCK make this a schema, maybe an optional `returns_type`
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
