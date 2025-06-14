// @slop claude_opus_4
// action_event.ts

import {is_promise} from '@ryanatkn/belt/async.js';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

import type {
	Action_Kind,
	Action_Phase,
	Action_Input,
	Action_Output,
	Action_Environment,
} from '$lib/action_types.js';
import type {Action_Spec} from '$lib/action_spec.js';
import {
	type Action_Event_Data_Union,
	type Action_Event_Data,
	type Action_Event_Step,
	type Action_Event_Environment,
	ACTION_STEP_TRANSITIONS,
	ACTION_PHASES_BY_KIND,
	type Request_Response_Action_Event_Data,
	type Remote_Notification_Action_Event_Data,
	type Local_Call_Action_Event_Data,
} from '$lib/action_event_types.js';
import type {Jsonrpc_Error_Json} from '$lib/jsonrpc.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';
import {stringify_zod_error, create_uuid} from '$lib/zod_helpers.js';
import type {Action_Method} from '$lib/action_metatypes.js';
import {action_spec_by_method} from '$lib/action_collections.js';
import {
	create_jsonrpc_request,
	create_jsonrpc_notification,
	create_jsonrpc_response,
} from '$lib/jsonrpc_helpers.js';

/**
 * Unified action event class that manages state transitions for all action types.
 * Works symmetrically on both frontend and backend based on the environment.
 */
export class Action_Event<
	T_Method extends Action_Method = Action_Method,
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
	T_Environment extends Action_Event_Environment = Action_Event_Environment,
> {
	readonly method: T_Method;
	readonly spec: Action_Spec;
	readonly environment: T_Environment;
	readonly kind: Action_Kind;
	readonly executor: Action_Environment;

	data: Action_Event_Data_Union<T_Method>;

	constructor(environment: T_Environment, spec: Action_Spec, input: T_Input) {
		this.environment = environment;
		this.spec = spec;
		this.method = spec.method as T_Method;
		this.kind = spec.kind;
		this.executor = environment.executor;

		const initial_phase = this.#get_initial_phase();
		if (!initial_phase) {
			throw jsonrpc_errors.internal_error(`No valid initial phase for ${spec.method}`);
		}

		this.data = this.#build_initial_data(initial_phase, input);
	}

	toJSON(): Action_Event_Data {
		return this.data;
	}

	/**
	 * Parse the input or output data according to the current phase.
	 * Transitions to 'parsed' step on success, 'failed' on error.
	 */
	parse(): this {
		if (this.data.step !== 'initial') {
			throw jsonrpc_errors.internal_error(`Cannot parse from step: ${this.data.step}`);
		}
		try {
			this.data = this.#parse_data();
		} catch (error) {
			this.#handle_parse_error(error);
		}
		return this;
	}

	/**
	 * Execute the handler synchronously.
	 * Throws if the handler returns a Promise.
	 */
	handle_sync(): void {
		if (this.data.step !== 'parsed') {
			throw jsonrpc_errors.internal_error(`Cannot handle from step: ${this.data.step}`);
		}
		this.data = this.#transition_to_handling();

		try {
			const output = this.#execute_handler();
			if (is_promise(output)) {
				throw jsonrpc_errors.internal_error(
					`Synchronous action returned a Promise: ${this.spec.method}`,
				);
			}
			this.data = this.#transition_to_handled(output);
		} catch (error) {
			this.#handle_handler_error(error);
		}
	}

	/**
	 * Execute the handler asynchronously.
	 * Works for both sync and async handlers.
	 */
	async handle_async(): Promise<void> {
		if (this.data.step !== 'parsed') {
			throw jsonrpc_errors.internal_error(`Cannot handle from step: ${this.data.step}`);
		}
		this.data = this.#transition_to_handling();

		try {
			const output = await this.#execute_handler();
			this.data = this.#transition_to_handled(output);
		} catch (error) {
			this.#handle_handler_error(error);
		}
	}

	/**
	 * Transition to a new phase.
	 * Only allowed from 'handled' step.
	 */
	transition_to_phase(phase: Action_Phase): this {
		if (!this.#can_transition_to_phase(phase)) {
			throw jsonrpc_errors.internal_error(
				`Cannot transition from ${this.data.phase}:${this.data.step} to ${phase}`,
			);
		}
		this.data = this.#build_phase_data(phase);
		return this;
	}

	/**
	 * Check if the action event has completed all phases.
	 */
	is_complete(): boolean {
		return this.data.step === 'handled' && !this.#has_next_phase();
	}

	/**
	 * Check if the action event has failed.
	 */
	is_failed(): boolean {
		return this.data.step === 'failed';
	}

	/**
	 * Check if the action event is in a terminal state.
	 */
	is_terminal(): boolean {
		return this.data.step === 'failed' || this.is_complete();
	}

	// Convenience getters
	get input(): T_Input | undefined {
		return 'input' in this.data ? (this.data.input as T_Input) : undefined;
	}

	get output(): T_Output | undefined {
		return 'output' in this.data ? (this.data.output as T_Output) : undefined;
	}

	get error(): Jsonrpc_Error_Json | undefined {
		return 'error' in this.data ? this.data.error : undefined;
	}

	// Private methods

	#get_valid_phases(): ReadonlyArray<Action_Phase> {
		const all_phases = ACTION_PHASES_BY_KIND[this.kind];
		const phases: Array<Action_Phase> = [];

		switch (this.kind) {
			case 'local_call':
				if (this.#can_executor_initiate()) {
					phases.push(...all_phases);
				}
				break;
			case 'request_response':
				if (this.#can_executor_initiate()) {
					phases.push('send_request', 'receive_response');
				}
				if (this.#can_executor_receive()) {
					phases.push('receive_request', 'send_response');
				}
				break;
			case 'remote_notification':
				if (this.#can_executor_initiate()) {
					phases.push('send');
				}
				if (this.#can_executor_receive()) {
					phases.push('receive');
				}
				break;
			default:
				throw new Unreachable_Error(this.kind);
		}

		return phases;
	}

	#can_executor_initiate(): boolean {
		return this.spec.initiator === this.executor || this.spec.initiator === 'both';
	}

	#can_executor_receive(): boolean {
		return this.kind === 'local_call'
			? this.#can_executor_initiate() // Local calls: same as initiate
			: this.spec.initiator === 'both' || this.spec.initiator !== this.executor; // Networked: opposite or both
	}

	#get_initial_phase(): Action_Phase | null {
		const valid_phases = this.#get_valid_phases();
		if (valid_phases.length === 0) return null;

		// Prefer initiating phases over receiving phases
		if (this.kind === 'request_response') {
			return valid_phases.includes('send_request') ? 'send_request' : 'receive_request';
		}
		if (this.kind === 'remote_notification') {
			return valid_phases.includes('send') ? 'send' : 'receive';
		}
		return 'execute'; // Local calls only have one phase
	}

	#build_initial_data(phase: Action_Phase, input: T_Input): Action_Event_Data_Union<T_Method> {
		return {
			kind: this.kind,
			phase,
			step: 'initial',
			method: this.method,
			executor: this.executor,
			input,
		} as Action_Event_Data_Union<T_Method>;
	}

	#should_parse_for_phase(phase: Action_Phase): 'input' | 'output' | null {
		switch (phase) {
			case 'send_request':
			case 'receive_request':
			case 'send':
			case 'receive':
			case 'execute':
				return 'input';
			case 'receive_response':
				return 'output';
			default:
				return null;
		}
	}

	#parse_data(): Action_Event_Data_Union<T_Method> {
		const parse_target = this.#should_parse_for_phase(this.data.phase);

		if (parse_target === 'input') {
			const parsed = this.spec.input.safeParse(this.data.input);
			if (!parsed.success) {
				throw jsonrpc_errors.invalid_params(
					`Invalid params for ${this.data.method}: ${stringify_zod_error(parsed.error)}`,
					{issues: parsed.error.issues},
				);
			}
			return {
				...this.data,
				step: 'parsed',
				input: parsed.data,
			} as Action_Event_Data_Union<T_Method>;
		}

		if (parse_target === 'output' && 'output' in this.data) {
			const parsed = this.spec.output.safeParse(this.data.output);
			if (!parsed.success) {
				throw jsonrpc_errors.internal_error(
					`Invalid output for ${this.data.method}: ${stringify_zod_error(parsed.error)}`,
					{issues: parsed.error.issues},
				);
			}
			return {
				...this.data,
				step: 'parsed',
				output: parsed.data,
			} as Action_Event_Data_Union<T_Method>;
		}

		// No parsing needed for this phase
		return {
			...this.data,
			step: 'parsed',
		} as Action_Event_Data_Union<T_Method>;
	}

	#handle_parse_error(error: unknown): void {
		this.data = {
			...this.data,
			step: 'failed',
			error: this.#to_jsonrpc_error(error),
		} as Action_Event_Data_Union<T_Method>;
	}

	#validate_step_transition(to_step: Action_Event_Step): void {
		const valid_transitions = ACTION_STEP_TRANSITIONS[this.data.step];
		if (!valid_transitions.includes(to_step)) {
			throw jsonrpc_errors.internal_error(
				`Invalid step transition: ${this.data.step} → ${to_step}`,
			);
		}
	}

	#transition_to_handling(): Action_Event_Data_Union<T_Method> {
		this.#validate_step_transition('handling');
		return {
			...this.data,
			step: 'handling',
		} as Action_Event_Data_Union<T_Method>;
	}

	#transition_to_handled(output?: T_Output): Action_Event_Data_Union<T_Method> {
		this.#validate_step_transition('handled');
		return this.#build_phase_data(this.data.phase, output);
	}

	#handle_handler_error(error: unknown): void {
		this.data = {
			...this.data,
			step: 'failed',
			error: this.#to_jsonrpc_error(error),
		} as Action_Event_Data_Union<T_Method>;
	}

	#build_phase_data(to_phase: Action_Phase, output?: T_Output): Action_Event_Data_Union<T_Method> {
		const current = this.data;

		// Handle step transitions within current phase
		if (to_phase === current.phase) {
			switch (this.kind) {
				case 'request_response':
					return this.#build_request_response_phase_data(
						current as Request_Response_Action_Event_Data<T_Method>,
						output,
					);
				case 'remote_notification':
					return this.#build_notification_phase_data(
						current as Remote_Notification_Action_Event_Data<T_Method>,
					);
				case 'local_call':
					return this.#build_local_call_phase_data(
						current as Local_Call_Action_Event_Data<T_Method>,
						output,
					);
				default:
					throw new Unreachable_Error(this.kind);
			}
		}

		// Handle phase transitions
		if (this.kind === 'request_response') {
			return this.#build_request_response_transition(
				current as Request_Response_Action_Event_Data<T_Method>,
				to_phase,
			);
		}

		// Notifications and local calls don't transition phases
		throw jsonrpc_errors.internal_error(`${this.kind} cannot transition phases`);
	}

	#build_request_response_phase_data(
		current: Request_Response_Action_Event_Data<T_Method>,
		output?: T_Output,
	): Request_Response_Action_Event_Data<T_Method> {
		switch (current.phase) {
			case 'send_request':
				return {
					...current,
					step: 'handled',
					request: create_jsonrpc_request(current.method, current.input, create_uuid()),
				} as Request_Response_Action_Event_Data<T_Method>;

			case 'receive_request':
				return {
					...current,
					step: 'handled',
					output: output!,
				} as Request_Response_Action_Event_Data<T_Method>;

			case 'send_response':
				if (!('request' in current) || !('output' in current)) {
					throw jsonrpc_errors.internal_error('Missing request or output for send_response');
				}
				return {
					...current,
					step: 'handled',
					response: create_jsonrpc_response(current.request.id, current.output),
				} as Request_Response_Action_Event_Data<T_Method>;

			case 'receive_response':
				return {
					...current,
					step: 'handled',
				} as Request_Response_Action_Event_Data<T_Method>;

			default:
				return current;
		}
	}

	#build_notification_phase_data(
		current: Remote_Notification_Action_Event_Data<T_Method>,
	): Remote_Notification_Action_Event_Data<T_Method> {
		const base_data = {
			...current,
			step: 'handled' as const,
		};

		if (current.phase === 'send') {
			return {
				...base_data,
				notification: create_jsonrpc_notification(current.method, current.input),
			};
		}

		return base_data;
	}

	#build_local_call_phase_data(
		current: Local_Call_Action_Event_Data<T_Method>,
		output?: T_Output,
	): Local_Call_Action_Event_Data<T_Method> {
		return {
			...current,
			step: 'handled' as const,
			output: output!,
		};
	}

	#build_request_response_transition(
		current: Request_Response_Action_Event_Data<T_Method>,
		to_phase: Action_Phase,
	): Request_Response_Action_Event_Data<T_Method> {
		if (to_phase === 'receive_response' && current.phase === 'send_request') {
			return {
				kind: 'request_response',
				phase: 'receive_response',
				step: 'initial',
				method: current.method,
				executor: this.executor,
				input: current.input,
				output: undefined as any,
				request: (current as any).request,
				response: undefined as any,
			};
		}

		if (to_phase === 'send_response' && current.phase === 'receive_request') {
			return {
				kind: 'request_response',
				phase: 'send_response',
				step: 'initial',
				method: current.method,
				executor: this.executor,
				input: current.input,
				output: (current as any).output,
				request: (current as any).request,
				response: undefined as any,
			};
		}

		throw jsonrpc_errors.internal_error(`Invalid phase transition: ${current.phase} → ${to_phase}`);
	}

	#has_next_phase(): boolean {
		const valid_phases = this.#get_valid_phases();
		const current_index = valid_phases.indexOf(this.data.phase);
		return current_index >= 0 && current_index < valid_phases.length - 1;
	}

	#can_transition_to_phase(phase: Action_Phase): boolean {
		const valid_phases = this.#get_valid_phases();
		if (!valid_phases.includes(phase)) {
			return false;
		}
		return this.data.step === 'handled';
	}

	#to_jsonrpc_error(error: unknown): Jsonrpc_Error_Json {
		if (error && typeof error === 'object' && 'code' in error && 'message' in error) {
			return error as Jsonrpc_Error_Json;
		}
		if (error instanceof Error) {
			return {
				code: jsonrpc_errors.internal_error().code,
				message: error.message,
			};
		}
		return {
			code: jsonrpc_errors.internal_error().code,
			message: 'Unknown error',
		};
	}

	#execute_handler(): undefined | T_Output | Promise<T_Output> {
		const handler = this.environment.lookup_action_handler(this.data.method, this.data.phase);
		if (!handler) {
			return undefined;
		}
		return handler(this);
	}
}

/**
 * Create an action event from a specification and input.
 */
export const create_action_event = <T_Method extends Action_Method>(
	environment: Action_Event_Environment,
	spec: Action_Spec,
	input: unknown,
): Action_Event<T_Method> => {
	return new Action_Event<T_Method>(environment, spec, input);
};

/**
 * Reconstruct an action event from JSON data.
 */
export const action_event_from_json = <T_Method extends Action_Method>(
	json: Action_Event_Data,
	environment: Action_Event_Environment,
): Action_Event<T_Method> => {
	const spec = action_spec_by_method.get(json.method);
	if (!spec) {
		throw new Error(`Unknown action method: ${json.method}`);
	}

	const event = create_action_event<T_Method>(environment, spec, json.input);
	event.data = json as Action_Event_Data_Union<T_Method>;

	return event;
};
