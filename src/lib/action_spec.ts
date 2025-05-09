import {z} from 'zod';

import {Uuid_With_Default, Datetime_Now} from '$lib/zod_helpers.js';
import type {Http_Method} from '$lib/api.js';
import {Action_Method} from '$lib/action_types.js';
import {Action_Direction} from '$lib/action_helpers.js';

// TODO BLOCK refactor with schemas.ts

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

export const Action_Spec_Base = z.object({
	method: Action_Method,
	type: z.enum(['Client_Action', 'Service_Action']),
	params: z.instanceof(z.ZodType),
	returns: z.string(),
	direction: Action_Direction,
});
export type Action_Spec_Base = z.infer<typeof Action_Spec_Base>;

export const Client_Action_Spec = Action_Spec_Base.extend({
	type: z.literal('Client_Action'),
});
export type Client_Action_Spec = z.infer<typeof Client_Action_Spec>;

export const Service_Action_Spec = Action_Spec_Base.extend({
	type: z.literal('Service_Action'),
	http_method: z.union([z.custom<Http_Method>(), z.null()]), // TODO maybe `http: {method: Http_Method, [...other http-specific config]}`
	auth: z.union([z.literal('authenticate'), z.literal('authorize'), z.null()]),
	response: z.instanceof(z.ZodType),
	// TODO some things like cant/shouldnt be done over websockets,
	// e.g. login/logout for cookies, but then maybe cookies should be the declarative property?
	// websockets: z.boolean().optional().default(false),
});
export type Service_Action_Spec = z.infer<typeof Service_Action_Spec>;

export const Action_Spec = z.union([Client_Action_Spec, Service_Action_Spec]);
export type Action_Spec = z.infer<typeof Action_Spec>;
