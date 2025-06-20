// @slop claude_opus_4

import {z} from 'zod';

import {Action_Method} from '$lib/action_metatypes.js';
import type {Action_Inputs, Action_Outputs} from '$lib/action_collections.js';
import {
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
	Jsonrpc_Notification,
	Jsonrpc_Error_Json,
} from '$lib/jsonrpc.js';
import {Action_Executor, Action_Kind} from '$lib/action_types.js';
import {Action_Event_Phase, Action_Event_Step} from '$lib/action_event_types.js';

// Base schema for all action event data
export const Action_Event_Data = z.object({
	kind: Action_Kind,
	phase: Action_Event_Phase,
	step: Action_Event_Step,
	method: Action_Method,
	executor: Action_Executor,
	input: z.unknown(),
	output: z.unknown().nullable(),
	error: Jsonrpc_Error_Json.nullable(),
	// Fields for specific kinds - always present but may be null
	request: Jsonrpc_Request.nullable(),
	response: Jsonrpc_Response_Or_Error.nullable(),
	notification: Jsonrpc_Notification.nullable(),
});
export type Action_Event_Data = z.infer<typeof Action_Event_Data>;

// Discriminated union types for narrowing
export type Action_Event_Request_Response_Data<T_Method extends Action_Method = Action_Method> =
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'initial';
			method: T_Method;
			executor: Action_Executor;
			input: unknown;
			output: null;
			error: null;
			request: null;
			response: null;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'parsed';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: null;
			response: null;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'handling';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: Jsonrpc_Request;
			response: null;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'handled';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: Jsonrpc_Request;
			response: null;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'send_request';
			step: 'failed';
			method: T_Method;
			executor: Action_Executor;
			input: unknown;
			output: null;
			error: Jsonrpc_Error_Json;
			request: Jsonrpc_Request | null;
			response: null;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'initial';
			method: T_Method;
			executor: Action_Executor;
			input: unknown;
			output: null;
			error: null;
			request: Jsonrpc_Request;
			response: null;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'parsed';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: Jsonrpc_Request;
			response: null;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'handling';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: Jsonrpc_Request;
			response: null;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'handled';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			error: null;
			request: Jsonrpc_Request;
			response: null;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_request';
			step: 'failed';
			method: T_Method;
			executor: Action_Executor;
			input: unknown;
			output: null;
			error: Jsonrpc_Error_Json;
			request: Jsonrpc_Request;
			response: null;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'initial';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			error: null;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'parsed';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			error: null;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'handling';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			error: null;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'handled';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			error: null;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'send_response';
			step: 'failed';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method] | null;
			error: Jsonrpc_Error_Json;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'initial';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: unknown;
			error: null;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'parsed';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			error: null;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'handling';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			error: null;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'handled';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			error: null;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
			notification: null;
	  }
	| {
			kind: 'request_response';
			phase: 'receive_response';
			step: 'failed';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method] | null;
			error: Jsonrpc_Error_Json;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response_Or_Error;
			notification: null;
	  };

export type Action_Event_Remote_Notification_Data<T_Method extends Action_Method = Action_Method> =
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'initial';
			method: T_Method;
			executor: Action_Executor;
			input: unknown;
			output: null;
			error: null;
			request: null;
			response: null;
			notification: null;
	  }
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'parsed';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: null;
			response: null;
			notification: null;
	  }
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'handling';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: null;
			response: null;
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'handled';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: null;
			response: null;
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'send';
			step: 'failed';
			method: T_Method;
			executor: Action_Executor;
			input: unknown;
			output: null;
			error: Jsonrpc_Error_Json;
			request: null;
			response: null;
			notification: Jsonrpc_Notification | null;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'initial';
			method: T_Method;
			executor: Action_Executor;
			input: unknown;
			output: null;
			error: null;
			request: null;
			response: null;
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'parsed';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: null;
			response: null;
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'handling';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: null;
			response: null;
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'handled';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: null;
			response: null;
			notification: Jsonrpc_Notification;
	  }
	| {
			kind: 'remote_notification';
			phase: 'receive';
			step: 'failed';
			method: T_Method;
			executor: Action_Executor;
			input: unknown;
			output: null;
			error: Jsonrpc_Error_Json;
			request: null;
			response: null;
			notification: Jsonrpc_Notification;
	  };

export type Action_Event_Local_Call_Data<T_Method extends Action_Method = Action_Method> =
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'initial';
			method: T_Method;
			executor: Action_Executor;
			input: unknown;
			output: null;
			error: null;
			request: null;
			response: null;
			notification: null;
	  }
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'parsed';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: null;
			response: null;
			notification: null;
	  }
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'handling';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: null;
			error: null;
			request: null;
			response: null;
			notification: null;
	  }
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'handled';
			method: T_Method;
			executor: Action_Executor;
			input: Action_Inputs[T_Method];
			output: Action_Outputs[T_Method];
			error: null;
			request: null;
			response: null;
			notification: null;
	  }
	| {
			kind: 'local_call';
			phase: 'execute';
			step: 'failed';
			method: T_Method;
			executor: Action_Executor;
			input: unknown;
			output: null;
			error: Jsonrpc_Error_Json;
			request: null;
			response: null;
			notification: null;
	  };

// Union type for all action event data
export type Action_Event_Data_Union<T_Method extends Action_Method = Action_Method> =
	| Action_Event_Request_Response_Data<T_Method>
	| Action_Event_Remote_Notification_Data<T_Method>
	| Action_Event_Local_Call_Data<T_Method>;
