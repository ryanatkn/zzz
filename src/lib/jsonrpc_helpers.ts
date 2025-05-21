// src/lib/jsonrpc_helpers.ts

import {DEV} from 'esm-env';

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

// TODO this maps http error codes to jsonrpc errors and loses information,
// but I'm thinking the source of truth should be in http error codes
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
		// TODO handle zod errors
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
