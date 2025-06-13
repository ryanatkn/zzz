// @slop claude_opus_4
// server/backend_action_event.ts

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Action_Method} from '$lib/action_metatypes.js';
import type {Action_Input, Action_Output, Action_Phase} from '$lib/action_types.js';
import type {Action_Spec} from '$lib/action_spec.js';
import {
	type Request_Response_Action_Event_Data,
	type Remote_Notification_Action_Event_Data,
	type Local_Call_Action_Event_Data,
	type Action_Event_Data,
	type Action_Event_Data_Union,
} from '$lib/action_event_types.js';
import {Action_Event} from '$lib/action_event.js';
import {action_spec_by_method} from '$lib/action_collections.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';
import {
	create_jsonrpc_request,
	create_jsonrpc_notification,
	create_jsonrpc_response,
} from '$lib/jsonrpc_helpers.js';
import {create_uuid} from '$lib/zod_helpers.js';

/**
 * Request/Response action event for backend.
 */
export class Backend_Request_Response_Action_Event<
	T_Method extends Action_Method = Action_Method,
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> extends Action_Event<
	T_Input,
	T_Output,
	Request_Response_Action_Event_Data<T_Method, T_Input, T_Output>,
	Action_Spec,
	Zzz_Server
> {
	readonly kind = 'request_response' as const;
	readonly executor = 'backend' as const;
	readonly valid_phases: ReadonlyArray<Action_Phase>;

	readonly server: Zzz_Server;

	constructor(spec: Action_Spec, environment: Zzz_Server, input: T_Input) {
		// Compute valid phases based on initiator
		const phases: Array<Action_Phase> = [];
		if (spec.initiator === 'backend' || spec.initiator === 'both') {
			phases.push('send_request', 'receive_response');
		}
		if (spec.initiator === 'frontend' || spec.initiator === 'both') {
			phases.push('receive_request', 'send_response');
		}

		const valid_phases = phases as ReadonlyArray<Action_Phase>;
		super(spec, environment, input);
		this.server = environment;
		this.valid_phases = valid_phases;
	}

	protected should_parse_for_phase(phase: Action_Phase): 'input' | 'output' | null {
		switch (phase) {
			case 'send_request':
			case 'receive_request':
				return 'input';
			case 'receive_response':
				return 'output';
			default:
				return null;
		}
	}

	build_phase_data(
		to_phase: Action_Phase,
		output?: T_Output,
	): Request_Response_Action_Event_Data<T_Method, T_Input, T_Output> {
		const current = this.data;

		// Handle step transitions within current phase
		if (to_phase === current.phase) {
			switch (current.phase) {
				case 'send_request':
					return {
						...current,
						step: 'handled',
						request: create_jsonrpc_request(current.method, current.input, create_uuid()),
					} as Request_Response_Action_Event_Data<T_Method, T_Input, T_Output>;

				case 'receive_request':
					return {
						...current,
						step: 'handled',
						output,
					} as Request_Response_Action_Event_Data<T_Method, T_Input, T_Output>;

				case 'send_response':
					if (!('request' in current) || !('output' in current)) {
						throw jsonrpc_errors.internal_error('Missing request or output for send_response');
					}
					return {
						...current,
						step: 'handled',
						response: create_jsonrpc_response(current.request.id, current.output),
					} as Request_Response_Action_Event_Data<T_Method, T_Input, T_Output>;

				case 'receive_response':
					return {
						...current,
						step: 'handled',
					} as Request_Response_Action_Event_Data<T_Method, T_Input, T_Output>;

				default:
					return current;
			}
		}

		// Handle phase transitions
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

		throw jsonrpc_errors.internal_error(`Invalid phase transition: ${current.phase} → ${to_phase}`);
	}
}

/**
 * Remote notification action event for backend.
 */
export class Backend_Remote_Notification_Action_Event<
	T_Method extends Action_Method = Action_Method,
	T_Input extends Action_Input = Action_Input,
> extends Action_Event<
	T_Input,
	void,
	Remote_Notification_Action_Event_Data<T_Method, T_Input>,
	Action_Spec,
	Zzz_Server
> {
	readonly kind = 'remote_notification' as const;
	readonly executor = 'backend' as const;
	readonly valid_phases: ReadonlyArray<Action_Phase>;

	readonly server: Zzz_Server;

	constructor(spec: Action_Spec, environment: Zzz_Server, input: T_Input) {
		// Compute valid phases based on initiator
		const phases: Array<Action_Phase> = [];
		if (spec.initiator === 'backend' || spec.initiator === 'both') {
			phases.push('send');
		}
		if (spec.initiator === 'frontend' || spec.initiator === 'both') {
			phases.push('receive');
		}

		const valid_phases = phases as ReadonlyArray<Action_Phase>;
		super(spec, environment, input);
		this.server = environment;
		this.valid_phases = valid_phases;
	}

	protected should_parse_for_phase(phase: Action_Phase): 'input' | 'output' | null {
		return phase === 'send' || phase === 'receive' ? 'input' : null;
	}

	build_phase_data(
		to_phase: Action_Phase,
	): Remote_Notification_Action_Event_Data<T_Method, T_Input> {
		const current = this.data;

		// Notifications don't transition phases
		if (to_phase !== current.phase) {
			throw jsonrpc_errors.internal_error(`Notifications cannot transition phases`);
		}

		// Handle step transition to handled
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
}

/**
 * Local call action event for backend.
 */
export class Backend_Local_Call_Action_Event<
	T_Method extends Action_Method = Action_Method,
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> extends Action_Event<
	T_Input,
	T_Output,
	Local_Call_Action_Event_Data<T_Method, T_Input, T_Output>,
	Action_Spec,
	Zzz_Server
> {
	readonly kind = 'local_call' as const;
	readonly executor = 'backend' as const;
	readonly valid_phases: ReadonlyArray<Action_Phase>;

	readonly server: Zzz_Server;

	constructor(spec: Action_Spec, environment: Zzz_Server, input: T_Input) {
		const phases =
			spec.initiator === 'backend' || spec.initiator === 'both' ? ['execute' as const] : [];
		const valid_phases = phases as ReadonlyArray<Action_Phase>;
		super(spec, environment, input);
		this.server = environment;
		this.valid_phases = valid_phases;
	}

	protected should_parse_for_phase(phase: Action_Phase): 'input' | 'output' | null {
		return phase === 'execute' ? 'input' : null;
	}

	build_phase_data(
		to_phase: Action_Phase,
		output?: T_Output,
	): Local_Call_Action_Event_Data<T_Method, T_Input, T_Output> {
		const current = this.data;

		// Local calls don't transition phases
		if (to_phase !== current.phase) {
			throw jsonrpc_errors.internal_error(`Local calls cannot transition phases`);
		}

		// Handle step transition to handled
		return {
			...current,
			step: 'handled' as const,
			...(output !== undefined && {output}),
		};
	}
}

export type Backend_Action_Event =
	| Backend_Request_Response_Action_Event
	| Backend_Remote_Notification_Action_Event
	| Backend_Local_Call_Action_Event;

export const create_backend_action_event = (
	server: Zzz_Server,
	spec: Action_Spec,
	input: unknown,
): Backend_Action_Event => {
	switch (spec.kind) {
		case 'request_response':
			return new Backend_Request_Response_Action_Event(spec, server, input);
		case 'remote_notification':
			return new Backend_Remote_Notification_Action_Event(spec, server, input);
		case 'local_call':
			return new Backend_Local_Call_Action_Event(spec, server, input);
	}
};

export const backend_action_event_from_json = (
	json: Action_Event_Data,
	server: Zzz_Server,
): Backend_Action_Event => {
	const spec = action_spec_by_method.get(json.method);
	if (!spec) {
		throw new Error(`Unknown action method: ${json.method}`);
	}

	const event = create_backend_action_event(server, spec, json.input);
	event.data = json as Action_Event_Data_Union;

	return event;
};
