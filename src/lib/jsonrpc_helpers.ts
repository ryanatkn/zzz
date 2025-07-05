import {DEV} from 'esm-env';

import {
	Jsonrpc_Error_Message,
	Jsonrpc_Error_Code,
	type Jsonrpc_Method,
	type Jsonrpc_Notification,
	type Jsonrpc_Notification_Params,
	type Jsonrpc_Request,
	type Jsonrpc_Request_Id,
	type Jsonrpc_Request_Params,
	Jsonrpc_Result,
	Jsonrpc_Response,
	Jsonrpc_Message,
	JSONRPC_VERSION,
	Jsonrpc_Singular_Message,
} from '$lib/jsonrpc.js';
import {Thrown_Jsonrpc_Error, JSONRPC_ERROR_CODES} from '$lib/jsonrpc_errors.js';

export const create_jsonrpc_request = (
	method: Jsonrpc_Method,
	params: Jsonrpc_Request_Params | undefined | void,
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

export const create_jsonrpc_response = (
	id: Jsonrpc_Request_Id,
	result: Jsonrpc_Result,
): Jsonrpc_Response => ({
	jsonrpc: JSONRPC_VERSION,
	id,
	result,
});

export const create_jsonrpc_notification = (
	method: Jsonrpc_Method,
	params: Jsonrpc_Notification_Params | undefined | void,
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

export const create_jsonrpc_error_message = (
	id: Jsonrpc_Error_Message['id'],
	error: Jsonrpc_Error_Message['error'],
): Jsonrpc_Error_Message => ({
	jsonrpc: JSONRPC_VERSION,
	id,
	error,
});

/**
 * Creates a JSON-RPC error response from any error.
 * Handles Jsonrpc_Error and regular Error objects.
 */
export const create_jsonrpc_error_message_from_thrown = (
	id: Jsonrpc_Request_Id,
	error: any,
): Jsonrpc_Error_Message => {
	let code: Jsonrpc_Error_Code = JSONRPC_ERROR_CODES.INTERNAL_ERROR;
	let message = 'Internal server error';
	let data = undefined;

	if (error instanceof Thrown_Jsonrpc_Error) {
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

export const to_jsonrpc_message_id = (message_or_id: unknown): Jsonrpc_Request_Id | null => {
	if (!message_or_id) return null;

	const maybe_id =
		typeof message_or_id === 'object' ? (message_or_id as {id?: unknown}).id : message_or_id;

	return is_jsonrpc_request_id(maybe_id) ? maybe_id : null;
};

// TODO @api probably parse with schema instead
export const is_jsonrpc_request_id = (id: unknown): id is Jsonrpc_Request_Id => {
	const type = typeof id;
	return type === 'string' || (type === 'number' && !Number.isNaN(id) && Number.isFinite(id));
};

export const is_jsonrpc_object = (message: unknown): message is {jsonrpc: typeof JSONRPC_VERSION} =>
	typeof message === 'object' &&
	message !== null &&
	!Array.isArray(message) &&
	(message as any).jsonrpc === JSONRPC_VERSION;

export const is_jsonrpc_message = (message: unknown): message is Jsonrpc_Message =>
	Array.isArray(message)
		? message.length > 0 && message.every((m) => is_jsonrpc_object(m))
		: is_jsonrpc_object(message);

export const is_jsonrpc_request = (message: unknown): message is Jsonrpc_Request =>
	is_jsonrpc_object(message) && 'method' in message && 'id' in message;

export const is_jsonrpc_notification = (message: unknown): message is Jsonrpc_Notification =>
	is_jsonrpc_object(message) && 'method' in message && !('id' in message);

export const is_jsonrpc_response = (message: unknown): message is Jsonrpc_Response =>
	is_jsonrpc_object(message) && 'result' in message && 'id' in message;

export const is_jsonrpc_error_message = (message: unknown): message is Jsonrpc_Error_Message =>
	is_jsonrpc_object(message) && 'error' in message && 'id' in message;

export const is_jsonrpc_singular_message = (
	message: unknown,
): message is Jsonrpc_Singular_Message => is_jsonrpc_object(message);
