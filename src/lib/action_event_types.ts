// @slop claude_opus_4
// action_event_types.ts

import {z} from 'zod';

import {
	Action_Kind,
	Action_Phase,
	Action_Input,
	Action_Output,
	Action_Environment,
} from '$lib/action_types.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {
	Jsonrpc_Request,
	Jsonrpc_Response,
	Jsonrpc_Error_Message,
	Jsonrpc_Response_Or_Error,
	Jsonrpc_Notification,
	Jsonrpc_Error_Json,
} from '$lib/jsonrpc.js';

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

export const Action_Event_Json = Action_Event_Data;
export type Action_Event_Json = z.infer<typeof Action_Event_Json>;

/**
 * Base interface for action event environments.
 * Both frontend (Zzz_App) and backend (Zzz_Server) must implement this.
 */
export interface Action_Event_Environment {
	lookup_action_handler: (
		method: Action_Method,
		phase: Action_Phase,
	) => ((event: any) => any) | undefined;
}

export type Request_Response_Action_Event_Data<
	T_Method extends Action_Method = Action_Method,
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> =
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
			input: T_Input;
	  }
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
	  }
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			request: Jsonrpc_Request;
	  }
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input?: T_Input;
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
			input: T_Input;
			request: Jsonrpc_Request;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			request: Jsonrpc_Request;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			output: T_Output;
			request: Jsonrpc_Request;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input?: T_Input;
			request: Jsonrpc_Request;
			error: Jsonrpc_Error_Json;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'initial';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			output: T_Output;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response | Jsonrpc_Error_Message;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'parsed';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			output: T_Output;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response | Jsonrpc_Error_Message;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			output: T_Output;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response | Jsonrpc_Error_Message;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			output: T_Output;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response | Jsonrpc_Error_Message;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			output?: T_Output;
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
			input: T_Input;
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
			input: T_Input;
			output: T_Output;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			output: T_Output;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			output: T_Output;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			output?: T_Output;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
			error: Jsonrpc_Error_Json;
	  };

export type Remote_Notification_Action_Event_Data<
	T_Method extends Action_Method = Action_Method,
	T_Input extends Action_Input = Action_Input,
> =
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
			input: T_Input;
	  }
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
	  }
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input?: T_Input;
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
			input: T_Input;
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input?: T_Input;
			notification: Jsonrpc_Notification;
			error: Jsonrpc_Error_Json;
	  };

export type Local_Call_Action_Event_Data<
	T_Method extends Action_Method = Action_Method,
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> =
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
			input: T_Input;
	  }
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'handling';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
	  }
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'handled';
			method: T_Method;
			executor: Action_Environment;
			input: T_Input;
			output: T_Output;
	  }
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'failed';
			method: T_Method;
			executor: Action_Environment;
			input?: T_Input;
			error: Jsonrpc_Error_Json;
	  };

export type Action_Event_Data_Union<
	T_Method extends Action_Method = Action_Method,
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> =
	| Request_Response_Action_Event_Data<T_Method, T_Input, T_Output>
	| Remote_Notification_Action_Event_Data<T_Method, T_Input>
	| Local_Call_Action_Event_Data<T_Method, T_Input, T_Output>;

export type Action_Event_Handler<
	T_Action_Event extends {data: Action_Event_Data},
	T_Data extends Action_Event_Data,
	T_Phase extends Action_Phase,
	T_Output = void,
> = (
	action_event: T_Action_Event & {
		data: Extract<T_Data, {phase: T_Phase; step: 'handling'}>;
	},
) => T_Output | Promise<T_Output>;

export type Batch_Action_Event_Data<T_Action_Event = unknown> =
	| {
			kind: 'batch';
			phase: 'batch';
			step: 'initial';
			executor: Action_Environment;
			raw_messages: Array<unknown>;
	  }
	| {
			kind: 'batch';
			phase: 'batch';
			step: 'parsed';
			executor: Action_Environment;
			raw_messages: Array<unknown>;
			action_events: Array<T_Action_Event>;
	  }
	| {
			kind: 'batch';
			phase: 'batch';
			step: 'handling';
			executor: Action_Environment;
			raw_messages: Array<unknown>;
			action_events: Array<T_Action_Event>;
	  }
	| {
			kind: 'batch';
			phase: 'batch';
			step: 'handled';
			executor: Action_Environment;
			raw_messages: Array<unknown>;
			action_events: Array<T_Action_Event>;
			responses: Array<unknown>;
	  }
	| {
			kind: 'batch';
			phase: 'batch';
			step: 'failed';
			executor: Action_Environment;
			raw_messages: Array<unknown>;
			action_events?: Array<T_Action_Event>;
			error: Jsonrpc_Error_Json;
	  };
