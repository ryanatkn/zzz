// @slop claude_opus_4
// action_event.ts

import type {Action_Method} from '$lib/action_metatypes.js';
import type {Action_Spec} from '$lib/action_spec.js';
import type {
	Action_Event_Environment,
	Action_Phase,
	Action_Step,
	Action_Kind,
} from '$lib/action_event_types.js';
import {Action_Event_Data} from '$lib/action_event_data.js';
import {
	validate_step_transition,
	validate_phase_transition,
	should_validate_output,
	create_parse_error,
	create_validation_error,
	create_handler_error,
	is_action_complete,
	create_initial_data,
	get_initial_phase,
	is_request_response,
	is_send_request_with_parsed_input,
	is_notification_send_with_parsed_input,
	to_jsonrpc_params,
	to_jsonrpc_result,
} from '$lib/action_event_helpers.js';
import type {Action_Event_Datas} from '$lib/action_collections.js';
import {parse_action_input, parse_action_output} from '$lib/action_collection_helpers.js';
import {
	create_jsonrpc_request,
	create_jsonrpc_response,
	create_jsonrpc_error_message,
	create_jsonrpc_notification,
} from '$lib/jsonrpc_helpers.js';
import {create_uuid} from '$lib/zod_helpers.js';
import type {
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
	Jsonrpc_Notification,
	Jsonrpc_Error_Json,
} from '$lib/jsonrpc.js';

// State change observer type
export type Action_Event_Change_Observer<T_Method extends Action_Method> = (
	event: Action_Event<T_Method>,
	old_data: Action_Event_Datas[T_Method],
	new_data: Action_Event_Datas[T_Method],
) => void;

/**
 * Action event that manages the lifecycle of an action through its state machine.
 */
export class Action_Event<
	T_Method extends Action_Method = Action_Method,
	T_Environment extends Action_Event_Environment = Action_Event_Environment,
	T_Phase extends Action_Phase = Action_Phase,
	T_Step extends Action_Step = Action_Step,
> {
	#data: Action_Event_Datas[T_Method];
	#observers: Set<Action_Event_Change_Observer<T_Method>> = new Set();

	readonly environment: T_Environment;
	readonly spec: Action_Spec;

	get data(): Action_Event_Datas[T_Method] & {phase: T_Phase; step: T_Step} {
		return this.#data as Action_Event_Datas[T_Method] & {phase: T_Phase; step: T_Step};
	}

	// TODO hacky but preserves the API
	// TODO maybe app/server should be frontend/backend? fe/be for brevity?
	get app(): T_Environment {
		if (this.environment.executor !== 'frontend') {
			throw new Error('`action_event.app` can only be accessed in frontend environments');
		}
		return this.environment;
	}

	get backend(): T_Environment {
		if (this.environment.executor !== 'backend') {
			throw new Error('`action_event.backend` can only be accessed in backend environments');
		}
		return this.environment;
	}

	constructor(environment: T_Environment, spec: Action_Spec, data: Action_Event_Datas[T_Method]) {
		this.environment = environment;
		this.spec = spec;
		this.#data = data;
	}

	/**
	 * Serialize for JSON.
	 */
	toJSON(): Action_Event_Datas[T_Method] {
		return this.#data;
	}

	/**
	 * Add observer for state changes.
	 */
	// TODO Consider middleware pattern for more complex scenarios
	observe(observer: Action_Event_Change_Observer<T_Method>): () => void {
		this.#observers.add(observer);
		return () => this.#observers.delete(observer);
	}

	/**
	 * Parse input data according to the action's schema.
	 */
	parse(): this {
		if (this.#data.step !== 'initial') {
			throw new Error(`Cannot parse from step '${this.#data.step}' - must be 'initial'`);
		}

		try {
			const parsed_input = parse_action_input(this.spec.method, this.#data.input);
			this.#transition_step('parsed', {input: parsed_input});
		} catch (error) {
			this.#fail(create_parse_error(error));
		}

		return this;
	}

	/**
	 * Execute the handler for the current phase.
	 */
	// TODO Add timeout support
	// TODO Add cancellation support
	async handle_async(): Promise<void> {
		if (this.#data.step !== 'parsed') {
			throw new Error(`Cannot handle from step '${this.#data.step}' - must be 'parsed'`);
		}

		// Add protocol messages if needed
		const updates = this.#create_handling_updates();
		this.#transition_step('handling', updates);

		const handler = this.environment.lookup_action_handler(this.spec.method, this.#data.phase);
		if (!handler) {
			this.#transition_step('handled');
			return;
		}

		try {
			const result = await handler(this);
			this.#complete_handling(result);
		} catch (error) {
			this.#fail(create_handler_error(error));
		}
	}

	/**
	 * Execute handler synchronously (only for sync local_call actions).
	 */
	handle_sync(): void {
		if (this.spec.kind !== 'local_call' || this.spec.async) {
			throw new Error('handle_sync can only be used with synchronous local_call actions');
		}

		if (this.#data.step !== 'parsed') {
			throw new Error(`Cannot handle from step '${this.#data.step}' - must be 'parsed'`);
		}

		this.#transition_step('handling');

		const handler = this.environment.lookup_action_handler(this.spec.method, this.#data.phase);
		if (!handler) {
			this.#transition_step('handled');
			return;
		}

		try {
			const result = handler(this);
			this.#complete_handling(result);
		} catch (error) {
			this.#fail(create_handler_error(error));
		}
	}

	/**
	 * Transition to a new phase.
	 */
	transition(phase: Action_Phase): void {
		if (this.#data.step !== 'handled') {
			throw new Error(`Cannot transition from step '${this.#data.step}' - must be 'handled'`);
		}

		validate_phase_transition(this.#data.phase, phase);

		// Create new data for the phase
		const new_data = this.#create_phase_data(phase);
		this.#set_data(new_data);
	}

	/**
	 * Check if the action event is complete.
	 */
	is_complete(): boolean {
		return is_action_complete(this.#data);
	}

	/**
	 * Set protocol-specific data.
	 */
	set_request(request: Jsonrpc_Request): void {
		this.#validate_protocol_setter('request', {
			kind: 'request_response',
			phase: 'receive_request',
		});
		this.#update_data({request});
	}

	set_response(response: Jsonrpc_Response_Or_Error): void {
		this.#validate_protocol_setter('response', {
			kind: 'request_response',
			phase: 'receive_response',
		});

		const output = 'result' in response ? response.result : null;
		this.#update_data({response, output});
	}

	set_notification(notification: Jsonrpc_Notification): void {
		this.#validate_protocol_setter('notification', {
			kind: 'remote_notification',
			phase: 'receive',
		});
		this.#update_data({notification});
	}

	#transition_step(step: Action_Step, updates?: Partial<Action_Event_Data>): void {
		validate_step_transition(this.#data.step, step);
		this.#update_data({...updates, step});
	}

	/** Shallowly merges `updates` with the current data. */
	#update_data(updates: Partial<Action_Event_Data>): void {
		const new_data = {...this.#data, ...updates} as Action_Event_Datas[T_Method];
		this.#set_data(new_data);
	}

	#set_data(new_data: Action_Event_Datas[T_Method]): void {
		const old_data = this.#data;
		this.#data = new_data;

		// Notify observers
		for (const observer of this.#observers) {
			observer(this, old_data, new_data);
		}
	}

	#fail(error: Jsonrpc_Error_Json): void {
		this.#transition_step('failed', {error});
	}

	#validate_protocol_setter(
		field: string,
		requirements: {kind: Action_Kind; phase: Action_Phase},
	): void {
		if (this.#data.kind !== requirements.kind || this.#data.phase !== requirements.phase) {
			throw new Error(`Can only set ${field} in ${requirements.phase} phase`);
		}
		if (this.#data.step !== 'initial') {
			throw new Error(`Can only set ${field} at initial step`);
		}
	}

	#create_handling_updates(): Partial<Action_Event_Data> {
		// Create protocol messages when transitioning to 'handling' step
		// We check for 'parsed' state since this method is called before the transition
		if (is_send_request_with_parsed_input(this.#data)) {
			return {
				request: create_jsonrpc_request(
					this.spec.method,
					to_jsonrpc_params(this.#data.input),
					create_uuid(),
				),
			};
		}

		if (is_notification_send_with_parsed_input(this.#data)) {
			return {
				notification: create_jsonrpc_notification(
					this.spec.method,
					to_jsonrpc_params(this.#data.input),
				),
			};
		}

		return {};
	}

	#complete_handling(result: unknown): void {
		if (result !== undefined && should_validate_output(this.spec.kind, this.#data.phase)) {
			try {
				const parsed_output = parse_action_output(this.spec.method, result);
				this.#transition_step('handled', {output: parsed_output});
			} catch (error) {
				this.#fail(create_validation_error('output', error));
			}
		} else {
			this.#transition_step('handled');
		}
	}

	#create_phase_data(phase: Action_Phase): Action_Event_Datas[T_Method] {
		const base_data = create_initial_data(
			this.#data.kind,
			phase,
			this.#data.method,
			this.#data.executor,
			this.#data.input,
		);

		// Carry forward data based on transition
		if (is_request_response(this.#data)) {
			if (phase === 'receive_response' && this.#data.request) {
				// Carry forward the request when transitioning to receive_response
				return {...base_data, request: this.#data.request} as Action_Event_Datas[T_Method];
			} else if (phase === 'send_response' && this.#data.request) {
				// Create the response when transitioning to send_response
				const response = this.#create_response_from_data();
				return {
					...base_data,
					output: this.#data.output,
					request: this.#data.request,
					response,
				} as Action_Event_Datas[T_Method];
			}
		}

		return base_data as Action_Event_Datas[T_Method];
	}

	#create_response_from_data(): Jsonrpc_Response_Or_Error {
		if (!is_request_response(this.#data) || !this.#data.request) {
			throw new Error('Cannot create response without request');
		}

		if (this.#data.error) {
			return create_jsonrpc_error_message(this.#data.request.id, this.#data.error);
		}

		const result = to_jsonrpc_result(this.#data.output);
		return create_jsonrpc_response(this.#data.request.id, result);
	}
}

// TODO not sure about this helper's design/location (should it be internal to the class constructor? a static method?)
/**
 * Create an action event from a spec and initial input.
 */
export const create_action_event = <T_Method extends Action_Method>(
	environment: Action_Event_Environment,
	spec: Action_Spec,
	input: unknown,
	initial_phase?: Action_Phase,
): Action_Event<T_Method> => {
	const phase = initial_phase || get_initial_phase(spec.kind, spec.initiator, environment.executor);
	if (!phase) {
		throw new Error(
			`Executor '${environment.executor}' cannot initiate action '${spec.method}' with initiator '${spec.initiator}'`,
		);
	}

	const initial_data = create_initial_data(
		spec.kind,
		phase,
		spec.method,
		environment.executor,
		input,
	) as Action_Event_Datas[T_Method];

	return new Action_Event(environment, spec, initial_data);
};

/**
 * Reconstruct an action event from serialized JSON data.
 */
export const create_action_event_from_json = <T_Method extends Action_Method>(
	json: Action_Event_Datas[T_Method],
	environment: Action_Event_Environment,
): Action_Event<T_Method> => {
	const spec = environment.lookup_action_spec(json.method);
	if (!spec) {
		throw new Error(`No spec found for method '${json.method}'`);
	}

	return new Action_Event(environment, spec, json);
};

// TODO how to avoid casting? this should generally be safe but we dont have schemas for each possible action event state
export const parse_action_event = (
	raw_json: unknown,
	environment: Action_Event_Environment,
): Action_Event => {
	const json = Action_Event_Data.parse(raw_json);
	return create_action_event_from_json(json as Action_Event_Datas[typeof json.method], environment);
};
