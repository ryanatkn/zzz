// @slop

import type {Action_Kind, Action_Phase, Action_Environment} from '$lib/action_types.js';
import type {Action_Method} from '$lib/action_metatypes.js';
import type {Action_Spec} from '$lib/action_spec.js';
import {
	type Action_Event_Step,
	type Action_Event_Data_Union,
	type Action_Event_Data,
	type Action_Event_Json,
	ACTION_STEP_TRANSITIONS,
	ACTION_PHASES_BY_KIND,
} from '$lib/action_event_types.js';
import {action_spec_by_method} from '$lib/action_collections.js';
import type {Action_Event} from '$lib/action_event.js';

// TODO BLOCK delete any of these that are not used

/**
 * Check if a step transition is valid.
 */
export const is_valid_step_transition = (from: Action_Event_Step, to: Action_Event_Step): boolean =>
	ACTION_STEP_TRANSITIONS[from].includes(to);

/**
 * Check if a phase is valid for an action kind.
 */
export const is_valid_phase_for_kind = (phase: Action_Phase, kind: Action_Kind): boolean =>
	ACTION_PHASES_BY_KIND[kind].includes(phase);

/**
 * Get valid phases for an action method.
 */
export const get_valid_phases_for_method = (method: Action_Method): ReadonlyArray<Action_Phase> => {
	const spec = action_spec_by_method.get(method);
	return spec ? ACTION_PHASES_BY_KIND[spec.kind] : [];
};

/**
 * Get valid phases for an executor type based on action spec.
 */
export const get_valid_phases_for_executor = (
	spec: Action_Spec,
	executor: Action_Environment,
): Array<Action_Phase> => {
	const all_phases = ACTION_PHASES_BY_KIND[spec.kind];

	// Local calls: check initiator
	if (spec.kind === 'local_call') {
		return can_executor_initiate(spec, executor) ? [...all_phases] : [];
	}

	// Request/response: determine based on initiator
	if (spec.kind === 'request_response') {
		const phases: Array<Action_Phase> = [];
		if (can_executor_initiate(spec, executor)) {
			phases.push('send_request', 'receive_response');
		}
		if (can_executor_receive(spec, executor)) {
			phases.push('receive_request', 'send_response');
		}
		return phases;
	}

	// Notifications: determine based on initiator
	if (spec.kind === 'remote_notification') {
		const phases: Array<Action_Phase> = [];
		if (can_executor_initiate(spec, executor)) {
			phases.push('send');
		}
		if (can_executor_receive(spec, executor)) {
			phases.push('receive');
		}
		return phases;
	}

	return [];
};

/**
 * Type guard to check if data is in a specific phase.
 */
export const is_in_phase = <T_Phase extends Action_Phase>(
	data: Action_Event_Data,
	phase: T_Phase,
): data is Extract<Action_Event_Data_Union, {phase: T_Phase}> => data.phase === phase;

/**
 * Type guard to check if data is in a specific step.
 */
export const is_in_step = <T_Step extends Action_Event_Step>(
	data: Action_Event_Data,
	step: T_Step,
): data is Extract<Action_Event_Data_Union, {step: T_Step}> => data.step === step;

/**
 * Type guard to check if data is in a specific phase and step.
 */
export const is_in_phase_and_step = <
	T_Phase extends Action_Phase,
	T_Step extends Action_Event_Step,
>(
	data: Action_Event_Data,
	phase: T_Phase,
	step: T_Step,
): data is Extract<Action_Event_Data_Union, {phase: T_Phase; step: T_Step}> =>
	data.phase === phase && data.step === step;

/**
 * Check if an action event is ready for handling.
 */
export const is_ready_for_handling = (data: Action_Event_Data): boolean => data.step === 'parsed';

/**
 * Check if an action event is complete within its current phase.
 */
export const is_phase_complete = (data: Action_Event_Data): boolean => data.step === 'handled';

/**
 * Check if an action event has failed.
 */
export const is_failed = (data: Action_Event_Data): boolean => data.step === 'failed';

/**
 * Check if an action event is terminal (can't progress further in current phase).
 */
export const is_terminal_in_phase = (data: Action_Event_Data): boolean =>
	data.step === 'handled' || data.step === 'failed';

/**
 * Get the next logical phase for a request/response action.
 */
export const get_next_request_response_phase = (
	current_phase: Action_Phase,
): Action_Phase | null => {
	switch (current_phase) {
		case 'send_request':
			return 'receive_response';
		case 'receive_request':
			return 'send_response';
		default:
			return null;
	}
};

/**
 * Check if an action event JSON represents a specific kind.
 */
export const is_action_event_kind = (json: Action_Event_Json, kind: Action_Kind): boolean =>
	json.kind === kind;

/**
 * Extract error information from action event data.
 */
export const get_action_event_error = (
	data: Action_Event_Data,
): {code: number; message: string; data?: unknown} | null =>
	data.step === 'failed' && data.error ? data.error : null;

/**
 * Create a phase identifier string for logging/debugging.
 */
export const format_phase_step = (phase: Action_Phase, step: Action_Event_Step): string =>
	`${phase}:${step}`;

/**
 * Get a human-readable description of the current state.
 */
export const describe_action_event_state = (data: Action_Event_Data): string => {
	const base = `${data.method} - ${format_phase_step(data.phase, data.step)}`;
	const error = get_action_event_error(data);
	return error ? `${base} (error: ${error.message})` : base;
};

/**
 * Type guard to check if an object is an Action Event.
 */
export const is_action_event = (obj: unknown): obj is Action_Event =>
	!!obj &&
	typeof obj === 'object' &&
	'spec' in obj &&
	'context' in obj &&
	'data' in obj &&
	typeof (obj as any).parse === 'function' &&
	typeof (obj as any).handle === 'function';

/**
 * Type guard to check if JSON is a valid action event JSON.
 */
export const is_action_event_json = (obj: unknown): obj is Action_Event_Json =>
	obj !== null &&
	typeof obj === 'object' &&
	'kind' in obj &&
	'method' in obj &&
	'phase' in obj &&
	'step' in obj &&
	'executor' in obj;

/**
 * Get the appropriate initial phase for an action based on spec and executor.
 */
export const get_initial_phase = (
	spec: Action_Spec,
	executor: Action_Environment,
): Action_Phase | null => {
	const valid_phases = get_valid_phases_for_executor(spec, executor);

	if (valid_phases.length === 0) return null;

	// Prefer initiating phases over receiving phases
	if (spec.kind === 'request_response') {
		return valid_phases.includes('send_request') ? 'send_request' : 'receive_request';
	}

	if (spec.kind === 'remote_notification') {
		return valid_phases.includes('send') ? 'send' : 'receive';
	}

	return 'execute'; // Local calls only have one phase
};

/**
 * Check if an executor can initiate an action.
 */
export const can_executor_initiate = (spec: Action_Spec, executor: Action_Environment): boolean =>
	spec.initiator === executor || spec.initiator === 'both';

/**
 * Check if an executor can receive an action.
 */
export const can_executor_receive = (spec: Action_Spec, executor: Action_Environment): boolean =>
	spec.kind === 'local_call'
		? can_executor_initiate(spec, executor) // Local calls: same as initiate
		: spec.initiator === 'both' || spec.initiator !== executor; // Networked: opposite or both

/**
 * Get all valid step values.
 */
export const get_all_steps = (): Array<Action_Event_Step> =>
	Object.keys(ACTION_STEP_TRANSITIONS) as Array<Action_Event_Step>;

/**
 * Check if action event data represents a request.
 */
export const is_request_phase = (phase: Action_Phase): boolean =>
	phase === 'send_request' || phase === 'receive_request';

/**
 * Check if action event data represents a response.
 */
export const is_response_phase = (phase: Action_Phase): boolean =>
	phase === 'send_response' || phase === 'receive_response';

/**
 * Check if action event data represents a notification.
 */
export const is_notification_phase = (phase: Action_Phase): boolean =>
	phase === 'send' || phase === 'receive';

/**
 * Get the action spec for a method, with type narrowing.
 */
export const get_action_spec = (method: Action_Method): Action_Spec | undefined =>
	action_spec_by_method.get(method);

/**
 * Type guard for checking if a spec exists.
 */
export const has_action_spec = (method: Action_Method): boolean =>
	action_spec_by_method.has(method);
