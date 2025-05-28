import {DEV} from 'esm-env';

import {
	JSONRPC_VERSION,
	Jsonrpc_Error_Message,
	Jsonrpc_Error_Code,
	Jsonrpc_Singular_Message,
	type Jsonrpc_Method,
	type Jsonrpc_Notification,
	type Jsonrpc_Notification_Params,
	type Jsonrpc_Request,
	type Jsonrpc_Request_Id,
	type Jsonrpc_Request_Params,
} from '$lib/jsonrpc.js';
import {Jsonrpc_Error, JSONRPC_ERROR_CODES} from '$lib/jsonrpc_errors.js';

export const create_jsonrpc_request = (
	method: Jsonrpc_Method,
	params: Jsonrpc_Request_Params | void,
	id: Jsonrpc_Request_Id,
): Jsonrpc_Request => {
	const message: Jsonrpc_Request = {
		jsonrpc: JSONRPC_VERSION,
		id,
		method,
	};
	if (params !== undefined) {
		message.params = params;
	}

	return message;
};

// TODO currently unused, currently all actions are requests
export const create_jsonrpc_notification = (
	method: Jsonrpc_Method,
	params: Jsonrpc_Notification_Params | void,
): Jsonrpc_Notification => {
	const message: Jsonrpc_Notification = {
		jsonrpc: JSONRPC_VERSION,
		method,
	};
	if (params !== undefined) {
		message.params = params;
	}

	return message;
};

/**
 * Creates a JSON-RPC error response from any error.
 * Handles Jsonrpc_Error and regular Error objects.
 */
export const create_jsonrpc_error = (id: Jsonrpc_Request_Id, error: any): Jsonrpc_Error_Message => {
	let code: Jsonrpc_Error_Code = JSONRPC_ERROR_CODES.INTERNAL_ERROR;
	let message = 'Internal server error';
	let data = undefined;

	if (error instanceof Jsonrpc_Error) {
		// Use the error directly
		code = error.code;
		message = error.message;
		data = error.data;
	} else if (error instanceof Error) {
		message = error.message;
		// Include stack trace in development mode
		if (DEV) {
			data = {stack: error.stack};
		}
	}

	return {
		jsonrpc: JSONRPC_VERSION,
		id,
		error: {
			code,
			message,
			data,
		},
	};
};

export const to_jsonrpc_message_id = (
	message_or_id: Jsonrpc_Request_Id | Jsonrpc_Singular_Message | null,
): Jsonrpc_Request_Id | null => {
	if (!message_or_id) {
		return null;
	}

	const type = typeof message_or_id;
	if (type === 'string' || type === 'number') {
		return message_or_id as Jsonrpc_Request_Id;
	}

	return (message_or_id as any).id ?? null;
};
