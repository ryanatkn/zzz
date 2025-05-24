// src/lib/jsonrpc_helpers.ts

import {DEV} from 'esm-env';

import {
	JSONRPC_VERSION,
	JSONRPCError,
	JSONRPCSingularMessage,
	type JSONRPCMethod,
	type JSONRPCNotification,
	type JSONRPCNotificationParams,
	type JSONRPCRequest,
	type JSONRPCRequestId,
	type JSONRPCRequestParams,
} from '$lib/jsonrpc.js';
import {Jsonrpc_Error, JSONRPC_ERROR_CODES, type Jsonrpc_Error_Code} from '$lib/jsonrpc_errors.js';

export const create_jsonrpc_request = (
	method: JSONRPCMethod,
	params: JSONRPCRequestParams | void,
	id: JSONRPCRequestId,
): JSONRPCRequest => {
	const message: JSONRPCRequest = {
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
	method: JSONRPCMethod,
	params: JSONRPCNotificationParams | void,
): JSONRPCNotification => {
	const message: JSONRPCNotification = {
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
export const create_jsonrpc_error = (id: JSONRPCRequestId, error: any): JSONRPCError => {
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
	} else if (typeof error === 'object' && error !== null) {
		// Handle objects with status/message (legacy Api_Error compatibility)
		if ('status' in error && 'message' in error) {
			message = error.message || 'Unknown error';
			// Don't include status in data since we're using JSON-RPC codes
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
	message_or_id: JSONRPCRequestId | JSONRPCSingularMessage | null,
): JSONRPCRequestId | null => {
	if (!message_or_id) {
		return null;
	}

	const type = typeof message_or_id;
	if (type === 'string' || type === 'number') {
		return message_or_id as JSONRPCRequestId;
	}

	return (message_or_id as any).id ?? null;
};
