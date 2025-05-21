// src/lib/jsonrpc_helpers.ts

import {
	JSONRPC_INTERNAL_ERROR,
	JSONRPC_INVALID_PARAMS,
	JSONRPC_METHOD_NOT_FOUND,
	JSONRPC_VERSION,
	JSONRPCError,
	type JSONRPCMethod,
	type JSONRPCNotification,
	type JSONRPCNotificationParams,
	type JSONRPCRequest,
	type JSONRPCRequestId,
	type JSONRPCRequestParams,
} from '$lib/jsonrpc.js';
import {Api_Error} from '$lib/api.js';

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

export const create_jsonrpc_error = (id: JSONRPCRequestId, error: any): JSONRPCError => {
	let code = JSONRPC_INTERNAL_ERROR;
	let message = 'Internal server error';
	let data = undefined;

	if (error instanceof Api_Error) {
		// Map HTTP status codes to JSON-RPC error codes
		switch (error.status) {
			case 400:
				code = JSONRPC_INVALID_PARAMS;
				message = error.message || 'invalid params';
				break;
			case 404:
				code = JSONRPC_METHOD_NOT_FOUND;
				message = error.message || 'method not found';
				break;
			default:
				code = JSONRPC_INTERNAL_ERROR;
				message = error.message || 'internal server error';
		}
	} else if (error instanceof Error) {
		message = error.message;
		// Include stack trace in development mode
		if (process.env.NODE_ENV === 'development') {
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
