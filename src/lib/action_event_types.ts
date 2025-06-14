// @slop claude_opus_4
// action_event_types.ts

import {z} from 'zod';

import {Action_Kind, Action_Phase, Action_Input, Action_Environment} from '$lib/action_types.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {
	Jsonrpc_Request,
	Jsonrpc_Response,
	Jsonrpc_Error_Message,
	Jsonrpc_Response_Or_Error,
	Jsonrpc_Notification,
	Jsonrpc_Error_Json,
} from '$lib/jsonrpc.js';
import type {Action_Inputs, Action_Outputs} from '$lib/action_collections.js';

export const Action_Event_Step = z.enum(['initial', 'parsed', 'handling', 'handled', 'failed']);
export type Action_Event_Step = z.infer<typeof Action_Event_Step>;

export const ACTION_STEP_TRANSITIONS: Record<
	Action_Event_Step,
	ReadonlyArray<Action_Event_Step>
> = {
	initial: ['parsed', 'failed'],
	parsed: ['handling', 'failed'],
	handling: ['handled', 'failed'],
	handled: [],
	failed: [],
};

export const ACTION_PHASES_BY_KIND: Record<Action_Kind, ReadonlyArray<Action_Phase>> = {
	request_response: ['send_request', 'receive_request', 'send_response', 'receive_response'],
	remote_notification: ['send', 'receive'],
	local_call: ['execute'],
};

export const Action_Event_Data = z.object({
	kind: Action_Kind,
	phase: Action_Phase,
	step: Action_Event_Step,
	method: Action_Method,
	executor: Action_Environment,
	input: z.unknown().optional(),
	output: z.unknown().optional(),
	error: Jsonrpc_Error_Json.optional(),
});
export type Action_Event_Data = z.infer<typeof Action_Event_Data>;

/**
 * Base interface for action event environments.
 * Both frontend (Zzz_App) and backend (Zzz_Server) must implement this.
 * The environment provides the context-specific capabilities and handlers.
 */
export interface Action_Event_Environment {
	/**
	 * The executor type of this environment (frontend or backend).
	 */
	readonly executor: Action_Environment;

	/**
	 * Lookup a handler for a specific method and phase.
	 * Returns undefined if no handler is registered.
	 */
	lookup_action_handler: (
		method: Action_Method,
		phase: Action_Phase,
	) => ((event: any) => any) | undefined;
}

export type Request_Response_Action_Event_Data<T_Method extends Action_Method = Action_Method> =
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'initial';
			method: T_Method;
			executor: Action_Environment;
			input: unknown;
	  }
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'parsed';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
	  }
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
	  }
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			request: Jsonrpc_Request;
	  }
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input?: Action_Inputs[T_Method];
			error: Jsonrpc_Error_Json;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'initial';
			method: T_Method;
			executor: Action_Environment;
			input: unknown;
			request: Jsonrpc_Request;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'parsed';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			request: Jsonrpc_Request;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			request: Jsonrpc_Request;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			request: Jsonrpc_Request;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input?: Action_Inputs[T_Method];
			request: Jsonrpc_Request;
			error: Jsonrpc_Error_Json;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'initial';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			request: Jsonrpc_Request;
			response: Jsonrpc_Response | Jsonrpc_Error_Message;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'parsed';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			request: Jsonrpc_Request;
			response: Jsonrpc_Response | Jsonrpc_Error_Message;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			request: Jsonrpc_Request;
			response: Jsonrpc_Response | Jsonrpc_Error_Message;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			request: Jsonrpc_Request;
			response: Jsonrpc_Response | Jsonrpc_Error_Message;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			output?: Action_Outputs[T_Method];
			request: Jsonrpc_Request;
			response: Jsonrpc_Response | Jsonrpc_Error_Message;
			error: Jsonrpc_Error_Json;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'initial';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			output: unknown;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'parsed';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			output?: Action_Outputs[T_Method];
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
			error: Jsonrpc_Error_Json;
	  };

export type Remote_Notification_Action_Event_Data<T_Method extends Action_Method = Action_Method> =
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'initial';
			method: T_Method;
			executor: Action_Environment;
			input: unknown;
	  }
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'parsed';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
	  }
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
	  }
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input?: Action_Inputs[T_Method];
			error: Jsonrpc_Error_Json;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'initial';
			method: T_Method;
			executor: Action_Environment;
			input: unknown;
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'parsed';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input?: Action_Inputs[T_Method];
			notification: Jsonrpc_Notification;
			error: Jsonrpc_Error_Json;
	  };

export type Local_Call_Action_Event_Data<T_Method extends Action_Method = Action_Method> =
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'initial';
			method: T_Method;
			executor: Action_Environment;
			input: unknown;
	  }
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'parsed';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
	  }
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
	  }
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
	  }
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input?: Action_Inputs[T_Method];
			error: Jsonrpc_Error_Json;
	  };

export type Action_Event_Data_Union<T_Method extends Action_Method = Action_Method> =
	| Request_Response_Action_Event_Data<T_Method>
	| Remote_Notification_Action_Event_Data<T_Method>
	| Local_Call_Action_Event_Data<T_Method>;
