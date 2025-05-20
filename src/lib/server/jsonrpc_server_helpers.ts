import type {Logger} from '@ryanatkn/belt/log.js';

import {
	JSONRPC_VERSION,
	type JSONRPCResponse,
	type JSONRPCError,
	JSONRPC_PARSE_ERROR,
	JSONRPC_INVALID_REQUEST,
	JSONRPC_METHOD_NOT_FOUND,
	JSONRPC_INVALID_PARAMS,
	JSONRPC_INTERNAL_ERROR,
	JSONRPCNotification,
	JSONRPCRequest,
	type JSONRPCRequestId,
} from '$lib/jsonrpc.js';
import {Api_Error} from '$lib/api.js';

/**
 * Handler for JSON-RPC methods
 */
export type Jsonrpc_Method_Handler = (params: Record<string, any>) => Promise<any>;

/**
 * Handler for processing JSON-RPC requests
 */
export type Jsonrpc_Request_Handler = (
	request: JSONRPCRequest,
) => Promise<JSONRPCResponse | JSONRPCError>;

/**
 * Handler for processing JSON-RPC notifications
 */
export type Jsonrpc_Notification_Handler = (notification: JSONRPCNotification) => Promise<void>;

/**
 * Configuration options for the JSON-RPC server
 */
export interface Handle_Jsonrpc_Request_Options {
	data: any;

	/**
	 * Handler for processing JSON-RPC requests
	 */
	onrequest: Jsonrpc_Request_Handler;

	/**
	 * Handler for processing JSON-RPC notifications
	 */
	onnotification: Jsonrpc_Notification_Handler;

	/**
	 * Optional log instance
	 */
	log?: Logger | null;
}

/**
 * Process a JSON-RPC request and return a response.
 */
export const handle_jsonrpc_request = async (
	options: Handle_Jsonrpc_Request_Options,
): Promise<JSONRPCResponse | JSONRPCError | null> => {
	const {data, onrequest, onnotification, log} = options;

	const id: JSONRPCRequestId | undefined | null = data?.id; // include null for completeness

	try {
		// First attempt to validate as a request
		const parse_result = JSONRPCRequest.safeParse(data);

		if (parse_result.success) {
			const request = parse_result.data;
			try {
				return await onrequest(request);
			} catch (error) {
				log?.error(`Error processing JSON-RPC request:`, error);
				return create_jsonrpc_error(request.id, error);
			}
		} else {
			// If it's not a valid request, check if it's a notification
			const notification_parse = JSONRPCNotification.safeParse(data);
			if (notification_parse.success) {
				const notification = notification_parse.data;
				try {
					await onnotification(notification);
				} catch (error) {
					log?.error(`Error processing JSON-RPC notification:`, error);
					// No response for notifications, so just log the error
				}
				return null; // No response for notifications
			}

			// If neither a valid request nor notification, it's an invalid request
			if (id == null) {
				// For notifications we can't return an error
				log?.error('JSON-RPC invalid request:', parse_result.error);
				return null;
			}
			return {
				jsonrpc: JSONRPC_VERSION,
				id,
				error: {
					code: JSONRPC_INVALID_REQUEST,
					message: 'invalid request',
				},
			};
		}
	} catch (error) {
		// If we can't even parse the JSON properly
		log?.error('JSON-RPC parse error:', error);
		if (id == null) {
			// For notifications we can't return an error
			return null;
		}
		return {
			jsonrpc: JSONRPC_VERSION,
			id,
			error: {
				code: JSONRPC_PARSE_ERROR,
				message: 'parse error',
			},
		};
	}
};

// TODO BLOCK this is probably wrong, causes a back and forth, rethink the module's abstraction, users should be able to interface with any Api_Result
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
