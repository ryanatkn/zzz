import {z} from 'zod';

import {Uuid, Uuid_With_Default, Datetime_Now} from '$lib/zod_helpers.js';
import type {Http_Method} from '$lib/api.js';
import {Action_Method} from '$lib/action_types.js';
import {Action_Direction} from '$lib/schemas.js';

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

/**
 * Base schema for action specifications.
 */
export const Action_Spec_Base = z.object({
	method: Action_Method,
	direction: Action_Direction,
	params: z.instanceof(z.ZodType),
});
export type Action_Spec_Base = z.infer<typeof Action_Spec_Base>;

/**
 * Schema for client-only action specifications.
 */
export const Client_Action_Spec = Action_Spec_Base.extend({
	type: z.literal('Client_Action'),
	returns: z.string(),
});
export type Client_Action_Spec = z.infer<typeof Client_Action_Spec>;

/**
 * Schema for service action specifications.
 */
export const Service_Action_Spec = Action_Spec_Base.extend({
	type: z.literal('Service_Action'),
	http_method: z.union([z.custom<Http_Method>(), z.null()]),
	auth: z.union([z.literal('authenticate'), z.literal('authorize'), z.null()]),
	response: z.instanceof(z.ZodType),
	returns: z.string(),
});
export type Service_Action_Spec = z.infer<typeof Service_Action_Spec>;

/**
 * Union of all action specification types.
 */
export const Action_Spec = z.union([Client_Action_Spec, Service_Action_Spec]);
export type Action_Spec = z.infer<typeof Action_Spec>;
