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
import type {Http_Status} from '$lib/zod_helpers.js';

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
	id: Jsonrpc_Request_Id | null,
	error: any,
): Jsonrpc_Error_Message => {
	let code: Jsonrpc_Error_Code = JSONRPC_ERROR_CODES.internal_error;
	let message = 'internal server error';
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

/**
 * Normalizes input to JSON-RPC params format.
 * Returns undefined for null/undefined, wraps primitives in {value}.
 */
export const to_jsonrpc_params = (input: unknown): Record<string, any> | undefined => {
	// Handle void/undefined inputs
	if (input === undefined || input === null) {
		return undefined;
	}

	// Ensure it's an object for JSON-RPC params
	if (typeof input === 'object' && !Array.isArray(input)) {
		return input as Record<string, any>;
	}

	// Wrap non-object values
	return {value: input};
};

/**
 * Normalizes output to JSON-RPC result format.
 * Returns empty object for null/undefined, wraps primitives in {value}.
 */
export const to_jsonrpc_result = (output: unknown): Record<string, any> => {
	// JSON-RPC results must be objects
	if (output === null || output === undefined) {
		return {};
	}

	if (typeof output === 'object' && !Array.isArray(output)) {
		return output as Record<string, any>;
	}

	// Wrap non-object values
	return {value: output};
};

const jsonrpc_error_code_to_http_status_mapping: Array<[Jsonrpc_Error_Code, Http_Status]> = [
	[JSONRPC_ERROR_CODES.parse_error, 400],
	[JSONRPC_ERROR_CODES.invalid_request, 400],
	[JSONRPC_ERROR_CODES.method_not_found, 404],
	[JSONRPC_ERROR_CODES.invalid_params, 400],
	[JSONRPC_ERROR_CODES.internal_error, 500],
	[JSONRPC_ERROR_CODES.unauthenticated, 401],
	[JSONRPC_ERROR_CODES.forbidden, 403],
	[JSONRPC_ERROR_CODES.not_found, 404],
	[JSONRPC_ERROR_CODES.conflict, 409],
	[JSONRPC_ERROR_CODES.validation_error, 422],
	[JSONRPC_ERROR_CODES.rate_limited, 429],
	[JSONRPC_ERROR_CODES.service_unavailable, 503],
	[JSONRPC_ERROR_CODES.timeout, 504],
	[JSONRPC_ERROR_CODES.ai_provider_error, 502], // bad gateway - external service error
];

/**
 * Maps JSON-RPC error codes to HTTP status codes.
 */
export const JSONRPC_ERROR_CODE_TO_HTTP_STATUS: Record<Jsonrpc_Error_Code, Http_Status> =
	Object.fromEntries(jsonrpc_error_code_to_http_status_mapping) as Record<
		Jsonrpc_Error_Code,
		Http_Status
	>;

/**
 * Maps HTTP status codes to JSON-RPC error codes.
 */
export const HTTP_STATUS_TO_JSONRPC_ERROR_CODE: Record<Http_Status, Jsonrpc_Error_Code> =
	Object.fromEntries(
		jsonrpc_error_code_to_http_status_mapping.map(([jsonrpc_error_code, http_status]) => [
			http_status,
			jsonrpc_error_code,
		]),
	) as Record<Http_Status, Jsonrpc_Error_Code>;

export const jsonrpc_error_code_to_http_status = (code: Jsonrpc_Error_Code): Http_Status =>
	JSONRPC_ERROR_CODE_TO_HTTP_STATUS[code] || 500;

// TODO review, is slop
export const http_status_to_jsonrpc_error_code = (status: Http_Status): Jsonrpc_Error_Code =>
	HTTP_STATUS_TO_JSONRPC_ERROR_CODE[status] || JSONRPC_ERROR_CODES.internal_error; // TODO maybe unknown instead?
