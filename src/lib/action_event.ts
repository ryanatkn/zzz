// @slop
// action_event.ts

import {is_promise} from '@ryanatkn/belt/async.js';

import type {Action_Kind, Action_Phase, Action_Environment} from '$lib/action_types.js';
import type {Action_Spec} from '$lib/action_spec.js';
import {
	type Action_Event_Data,
	type Action_Event_Json,
	type Action_Event_Step,
	type Action_Event_Environment,
	ACTION_STEP_TRANSITIONS,
	ACTION_PHASES_BY_KIND,
} from '$lib/action_event_types.js';
import type {Jsonrpc_Error_Json} from '$lib/jsonrpc.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';
import {stringify_zod_error} from '$lib/zod_helpers.js';

/**
 * Abstract base class for action events - handles generic state machine behavior.
 */
export abstract class Action_Event<
	T_Data extends Action_Event_Data = Action_Event_Data,
	T_Spec extends Action_Spec = Action_Spec,
	T_Environment extends Action_Event_Environment = Action_Event_Environment,
> {
	abstract readonly kind: Action_Kind;
	abstract readonly executor: Action_Environment;

	readonly spec: T_Spec;
	readonly environment: T_Environment;
	readonly method: string;

	data: T_Data;

	/**
	 * Get valid phases for this action based on spec and executor type.
	 * Must be implemented by subclasses to provide executor-specific logic.
	 */
	abstract get valid_phases(): ReadonlyArray<Action_Phase>;

	/**
	 * Build phase data for a transition. Subclasses implement phase-specific logic.
	 * @param to_phase The phase to transition to
	 * @param handler_result Optional result from handler execution
	 */
	abstract build_phase_data(to_phase: Action_Phase, handler_result?: unknown): T_Data;

	/**
	 * Determine if the current phase expects input to be parsed.
	 * Subclasses implement based on their phase semantics.
	 */
	protected abstract should_parse_for_phase(phase: Action_Phase): 'input' | 'output' | null;

	constructor(spec: T_Spec, environment: T_Environment, input: unknown) {
		this.spec = spec;
		this.environment = environment;
		this.method = spec.method;

		const initial_phase = this.get_initial_phase();
		if (!initial_phase) {
			throw jsonrpc_errors.internal_error(`No valid initial phase for ${spec.method}`);
		}

		this.data = this.build_initial_data(initial_phase, input);
	}

	protected build_initial_data(phase: Action_Phase, input: unknown): T_Data {
		return {
			kind: this.kind,
			phase,
			step: 'initial',
			method: this.method,
			executor: this.executor,
			input,
		} as T_Data;
	}

	protected get_initial_phase(): Action_Phase | null {
		const all_phases = ACTION_PHASES_BY_KIND[this.kind];
		for (const phase of all_phases) {
			if (this.valid_phases.includes(phase)) {
				return phase;
			}
		}
		return null;
	}

	parse(): this {
		if (this.data.step !== 'initial') {
			throw jsonrpc_errors.internal_error(`Cannot parse from step: ${this.data.step}`);
		}
		try {
			this.data = this.parse_data();
		} catch (error) {
			this.handle_parse_error(error);
		}
		return this;
	}

	protected parse_data(): T_Data {
		const parse_target = this.should_parse_for_phase(this.data.phase);

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
			} as T_Data;
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
			} as T_Data;
		}

		// No parsing needed for this phase
		return {
			...this.data,
			step: 'parsed',
		} as T_Data;
	}

	protected handle_parse_error(error: unknown): void {
		this.data = {
			...this.data,
			step: 'failed',
			error: this.to_jsonrpc_error(error),
		} as T_Data;
	}

	handle_sync(): void {
		if (this.data.step !== 'parsed') {
			throw jsonrpc_errors.internal_error(`Cannot handle from step: ${this.data.step}`);
		}
		this.data = this.transition_to_handling();

		try {
			const result = this.execute_handler();
			if (is_promise(result)) {
				throw jsonrpc_errors.internal_error(
					`Synchronous action returned a Promise: ${this.spec.method}`,
				);
			}
			this.data = this.transition_to_handled(result);
		} catch (error) {
			this.handle_handler_error(error);
		}
	}

	async handle_async(): Promise<void> {
		if (this.data.step !== 'parsed') {
			throw jsonrpc_errors.internal_error(`Cannot handle from step: ${this.data.step}`);
		}
		this.data = this.transition_to_handling();

		try {
			const result = await this.execute_handler();
			this.data = this.transition_to_handled(result);
		} catch (error) {
			this.handle_handler_error(error);
		}
	}

	protected validate_step_transition(to_step: Action_Event_Step): void {
		const valid_transitions = ACTION_STEP_TRANSITIONS[this.data.step];
		if (!valid_transitions.includes(to_step)) {
			throw jsonrpc_errors.internal_error(
				`Invalid step transition: ${this.data.step} → ${to_step}`,
			);
		}
	}

	protected transition_to_handling(): T_Data {
		this.validate_step_transition('handling');
		return {
			...this.data,
			step: 'handling',
		} as T_Data;
	}

	protected transition_to_handled(result?: unknown): T_Data {
		this.validate_step_transition('handled');
		// Delegate to subclass to build phase-specific handled data
		return this.build_phase_data(this.data.phase, result);
	}

	protected handle_handler_error(error: unknown): void {
		this.data = {
			...this.data,
			step: 'failed',
			error: this.to_jsonrpc_error(error),
		} as T_Data;
	}

	transition_to_phase(phase: Action_Phase): this {
		if (!this.can_transition_to_phase(phase)) {
			throw jsonrpc_errors.internal_error(
				`Cannot transition from ${this.data.phase}:${this.data.step} to ${phase}`,
			);
		}
		this.data = this.build_phase_data(phase);
		return this;
	}

	protected has_next_phase(): boolean {
		const current_index = this.valid_phases.indexOf(this.data.phase);
		return current_index >= 0 && current_index < this.valid_phases.length - 1;
	}

	can_transition_to_phase(phase: Action_Phase): boolean {
		if (!this.valid_phases.includes(phase)) {
			return false;
		}
		return this.data.step === 'handled';
	}

	protected to_jsonrpc_error(error: unknown): Jsonrpc_Error_Json {
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

	/**
	 * Execute the handler for the current phase.
	 * Looks up handler from environment and executes it.
	 */
	protected execute_handler(): unknown | Promise<unknown> {
		const handler = this.environment.lookup_action_handler(this.data.method, this.data.phase);
		if (!handler) {
			return undefined;
		}
		return handler(this);
	}

	is_complete(): boolean {
		return this.data.step === 'handled' && !this.has_next_phase();
	}

	is_failed(): boolean {
		return this.data.step === 'failed';
	}

	is_terminal(): boolean {
		return this.data.step === 'failed' || this.is_complete();
	}

	toJSON(): Action_Event_Json {
		return this.data;
	}
}
