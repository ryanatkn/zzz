// @slop Claude Opus 4

import {
	type Action_Event_Phase,
	type Action_Event_Step,
	ACTION_EVENT_STEP_TRANSITIONS,
	ACTION_EVENT_PHASE_BY_KIND,
	ACTION_EVENT_PHASE_TRANSITIONS,
} from '$lib/action_event_types.js';
import type {
	Action_Event_Data,
	Action_Event_Request_Response_Data,
	Action_Event_Remote_Notification_Data,
	Action_Event_Local_Call_Data,
} from '$lib/action_event_data.js';
import type {Result} from '@ryanatkn/belt/result.js';

import type {Action_Method} from '$lib/action_metatypes.js';
import type {Action_Inputs} from '$lib/action_collections.js';
import type {Action_Executor, Action_Initiator, Action_Kind} from '$lib/action_types.js';
import type {Action_Event} from '$lib/action_event.js';
import type {Jsonrpc_Error_Json} from '$lib/jsonrpc.js';

// Type guards for action kinds
export const is_request_response = (
	data: Action_Event_Data,
): data is Action_Event_Request_Response_Data => data.kind === 'request_response';

export const is_remote_notification = (
	data: Action_Event_Data,
): data is Action_Event_Remote_Notification_Data => data.kind === 'remote_notification';

export const is_local_call = (data: Action_Event_Data): data is Action_Event_Local_Call_Data =>
	data.kind === 'local_call';

// Type guards for specific states
export const is_send_request = (
	data: Action_Event_Data,
): data is Action_Event_Request_Response_Data & {phase: 'send_request'} =>
	data.kind === 'request_response' && data.phase === 'send_request';

export const is_receive_request = (
	data: Action_Event_Data,
): data is Action_Event_Request_Response_Data & {phase: 'receive_request'} =>
	data.kind === 'request_response' && data.phase === 'receive_request';

export const is_send_response = (
	data: Action_Event_Data,
): data is Action_Event_Request_Response_Data & {phase: 'send_response'} =>
	data.kind === 'request_response' && data.phase === 'send_response';

export const is_receive_response = (
	data: Action_Event_Data,
): data is Action_Event_Request_Response_Data & {phase: 'receive_response'} =>
	data.kind === 'request_response' && data.phase === 'receive_response';

export const is_notification_send = (
	data: Action_Event_Data,
): data is Action_Event_Remote_Notification_Data & {phase: 'send'} =>
	data.kind === 'remote_notification' && data.phase === 'send';

export const is_notification_receive = (
	data: Action_Event_Data,
): data is Action_Event_Remote_Notification_Data & {phase: 'receive'} =>
	data.kind === 'remote_notification' && data.phase === 'receive';

export const is_execute = (
	data: Action_Event_Data,
): data is Action_Event_Local_Call_Data & {phase: 'execute'} =>
	data.kind === 'local_call' && data.phase === 'execute';

// Step state guards
export const is_initial = (
	data: Action_Event_Data,
): data is Action_Event_Data & {step: 'initial'} => data.step === 'initial';

export const is_parsed = (data: Action_Event_Data): data is Action_Event_Data & {step: 'parsed'} =>
	data.step === 'parsed';

export const is_handling = (
	data: Action_Event_Data,
): data is Action_Event_Data & {step: 'handling'} => data.step === 'handling';

export const is_handled = (
	data: Action_Event_Data,
): data is Action_Event_Data & {step: 'handled'} => data.step === 'handled';

export const is_failed = (data: Action_Event_Data): data is Action_Event_Data & {step: 'failed'} =>
	data.step === 'failed';

// Combined type guards for specific states with parsed input
// These check for 'parsed' or 'handling' steps since protocol messages
// are created when transitioning from 'parsed' to 'handling'
export const is_send_request_with_parsed_input = <T_Method extends Action_Method = Action_Method>(
	data: Action_Event_Data,
): data is Action_Event_Request_Response_Data<T_Method> & {
	phase: 'send_request';
	step: 'parsed' | 'handling';
	input: Action_Inputs[T_Method];
} => is_send_request(data) && (data.step === 'parsed' || data.step === 'handling');

export const is_notification_send_with_parsed_input = <
	T_Method extends Action_Method = Action_Method,
>(
	data: Action_Event_Data,
): data is Action_Event_Remote_Notification_Data<T_Method> & {
	phase: 'send';
	step: 'parsed' | 'handling';
	input: Action_Inputs[T_Method];
} => is_notification_send(data) && (data.step === 'parsed' || data.step === 'handling');

// Validation helpers
export const validate_step_transition = (from: Action_Event_Step, to: Action_Event_Step): void => {
	const valid_transitions = ACTION_EVENT_STEP_TRANSITIONS[from];
	if (!valid_transitions.includes(to)) {
		throw new Error(`Invalid step transition from '${from}' to '${to}'`);
	}
};

export const validate_phase_for_kind = (kind: Action_Kind, phase: Action_Event_Phase): void => {
	const valid_phases = ACTION_EVENT_PHASE_BY_KIND[kind];
	if (!valid_phases.includes(phase)) {
		throw new Error(`Invalid phase '${phase}' for ${kind} action`);
	}
};

export const validate_phase_transition = (
	from: Action_Event_Phase,
	to: Action_Event_Phase,
): void => {
	const expected = ACTION_EVENT_PHASE_TRANSITIONS[from];
	if (expected !== to) {
		throw new Error(`Invalid phase transition from '${from}' to '${to}'`);
	}
};

export const get_initial_phase = (
	kind: Action_Kind,
	initiator: Action_Initiator,
	executor: Action_Executor,
): Action_Event_Phase | null => {
	if (initiator !== 'both' && initiator !== executor) return null;

	switch (kind) {
		case 'request_response':
			return 'send_request';
		case 'remote_notification':
			return 'send';
		case 'local_call':
			return 'execute';
	}
};

export const should_validate_output = (kind: Action_Kind, phase: Action_Event_Phase): boolean =>
	(kind === 'request_response' && (phase === 'receive_request' || phase === 'receive_response')) ||
	(kind === 'local_call' && phase === 'execute');

export const is_action_complete = (data: Action_Event_Data): boolean => {
	if (data.step === 'failed') return true;
	if (data.step !== 'handled') return false;

	// Check if in terminal phase
	const next_phase = ACTION_EVENT_PHASE_TRANSITIONS[data.phase];
	return next_phase === null;
};

export const create_initial_data = (
	kind: Action_Kind,
	phase: Action_Event_Phase,
	method: Action_Method,
	executor: Action_Executor,
	input: unknown,
): Action_Event_Data => ({
	kind,
	phase,
	step: 'initial',
	method,
	executor,
	input,
	output: null,
	error: null,
	progress: null,
	request: null,
	response: null,
	notification: null,
});

export const extract_action_result = (
	event: Action_Event,
): Result<{value: Action_Event_Data['output']}, {error: Jsonrpc_Error_Json}> => {
	const {data} = event;

	if (data.step === 'handled') {
		return {ok: true, value: data.output};
	}

	if (data.step === 'failed') {
		return {ok: false, error: data.error};
	}

	// Programming error - event not in terminal state
	throw new Error(`cannot extract result: event in non-terminal state (step: ${data.step})`);
};
