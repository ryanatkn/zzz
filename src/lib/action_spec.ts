import {z} from 'zod';

import {Uuid_With_Default, Datetime_Now} from '$lib/zod_helpers.js';
import type {Http_Method} from '$lib/api.js';
import {Action_Method} from '$lib/action_metatypes.js';

/**
 * Centralized definitions for core action structures.
 * This module defines the core types and structures for the action system.
 */

/**
 * Base schema for all actions with common properties.
 */
export const Action_Base = z
	.object({
		id: Uuid_With_Default,
		created: Datetime_Now,
		method: Action_Method,
	})
	.strict();
export type Action_Base = z.infer<typeof Action_Base>;

export const Action_Kind = z.enum(['request_response', 'server_notification', 'client_local']);
export type Action_Kind = z.infer<typeof Action_Kind>;

export const Action_Spec_Base = z.object({
	method: Action_Method,
	kind: Action_Kind,
	// TODO BLOCK maybe `response_params`? not request_params tho? or some other way to handle req/res?
	params: z.instanceof(z.ZodType),
});
export type Action_Spec_Base = z.infer<typeof Action_Spec_Base>;

// Type for request_response actions (client requests, server responds)
export const Request_Response_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('request_response'),
	http_method: z.custom<Http_Method>(),
	auth: z.union([z.literal('authenticate'), z.literal('authorize'), z.null()]),
	response: z.instanceof(z.ZodType),
	returns: z.string(),
});
export type Request_Response_Action_Spec = z.infer<typeof Request_Response_Action_Spec>;

// Type for server_notification actions (server sends without a request)
export const Server_Notification_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('server_notification'),
});
export type Server_Notification_Action_Spec = z.infer<typeof Server_Notification_Action_Spec>;

// Type for client_local actions (that never leave the client)
export const Client_Local_Action_Spec = Action_Spec_Base.extend({
	kind: z.literal('client_local'),
	returns: z.string(),
});
export type Client_Local_Action_Spec = z.infer<typeof Client_Local_Action_Spec>;

// Union of all action spec types
export const Action_Spec = z.union([
	Request_Response_Action_Spec,
	Server_Notification_Action_Spec,
	Client_Local_Action_Spec,
]);
export type Action_Spec = z.infer<typeof Action_Spec>;
