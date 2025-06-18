// @slop claude_opus_4
// action_event_types.ts

import {z} from 'zod';
import type {Logger} from '@ryanatkn/belt/log.js';

import type {Action_Method} from '$lib/action_metatypes.js';
import type {Action_Executor} from '$lib/action_types.js';
import type {Action_Spec} from '$lib/action_spec.js';

// Core enums
export const Action_Step = z.enum(['initial', 'parsed', 'handling', 'handled', 'failed']);
export type Action_Step = z.infer<typeof Action_Step>;

export const Action_Phase = z.enum([
	'send_request',
	'receive_request',
	'send_response',
	'receive_response',
	'send',
	'receive',
	'execute',
]);
export type Action_Phase = z.infer<typeof Action_Phase>;

export const Action_Kind = z.enum(['request_response', 'remote_notification', 'local_call']);
export type Action_Kind = z.infer<typeof Action_Kind>;

// Step transitions
export const STEP_TRANSITIONS = {
	initial: ['parsed', 'failed'],
	parsed: ['handling', 'failed'],
	handling: ['handled', 'failed'],
	handled: [],
	failed: [],
} as Record<Action_Step, ReadonlyArray<Action_Step>>;

// Phase configurations by kind
export const PHASE_BY_KIND = {
	request_response: ['send_request', 'receive_request', 'send_response', 'receive_response'],
	remote_notification: ['send', 'receive'],
	local_call: ['execute'],
} as Record<Action_Kind, ReadonlyArray<Action_Phase>>;

// Phase transitions
export const PHASE_TRANSITIONS = {
	send_request: 'receive_response',
	receive_request: 'send_response',
	send_response: null,
	receive_response: null,
	send: null,
	receive: null,
	execute: null,
} as Record<Action_Phase, Action_Phase | null>;

// Environment interface
export interface Action_Event_Environment {
	readonly executor: Action_Executor;
	lookup_action_handler: (
		method: Action_Method,
		phase: Action_Phase,
	) => ((event: any) => any) | undefined;
	lookup_action_spec: (method: Action_Method) => Action_Spec | undefined;
	readonly log?: Logger | null;
}
