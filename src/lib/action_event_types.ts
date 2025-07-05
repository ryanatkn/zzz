// @slop claude_opus_4

import {z} from 'zod';
import type {Logger} from '@ryanatkn/belt/log.js';

import type {Action_Method} from '$lib/action_metatypes.js';
import type {Action_Executor, Action_Kind} from '$lib/action_types.js';
import type {Action_Spec_Union} from '$lib/action_spec.js';
import type {Action_Peer} from '$lib/action_peer.js';
import type {Actions} from '$lib/actions.svelte.js';

export const Action_Event_Step = z.enum(['initial', 'parsed', 'handling', 'handled', 'failed']);
export type Action_Event_Step = z.infer<typeof Action_Event_Step>;

export const Action_Event_Phase = z.enum([
	'send_request',
	'receive_request',
	'send_response',
	'receive_response',
	'send',
	'receive',
	'execute',
]);
export type Action_Event_Phase = z.infer<typeof Action_Event_Phase>;

export const ACTION_EVENT_STEP_TRANSITIONS = {
	initial: ['parsed', 'failed'],
	parsed: ['handling', 'failed'],
	handling: ['handled', 'failed'],
	handled: [],
	failed: [],
} as Record<Action_Event_Step, ReadonlyArray<Action_Event_Step>>;

export const ACTION_EVENT_PHASE_BY_KIND = {
	request_response: ['send_request', 'receive_request', 'send_response', 'receive_response'],
	remote_notification: ['send', 'receive'],
	local_call: ['execute'],
} as Record<Action_Kind, ReadonlyArray<Action_Event_Phase>>;

export const ACTION_EVENT_PHASE_TRANSITIONS = {
	send_request: 'receive_response',
	receive_request: 'send_response',
	send_response: null,
	receive_response: null,
	send: null,
	receive: null,
	execute: null,
} as Record<Action_Event_Phase, Action_Event_Phase | null>;

export interface Action_Event_Environment {
	readonly executor: Action_Executor;
	peer: Action_Peer;
	lookup_action_handler: (
		method: Action_Method,
		phase: Action_Event_Phase,
	) => ((event: any) => any) | undefined;
	lookup_action_spec: (method: Action_Method) => Action_Spec_Union | undefined;
	readonly log?: Logger | null;
	// TODO feels hacky, added for optional tracking
	actions?: Actions;
}
