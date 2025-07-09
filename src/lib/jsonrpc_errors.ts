// @slop claude_opus_4

import {
	JSONRPC_INTERNAL_ERROR,
	JSONRPC_INVALID_PARAMS,
	JSONRPC_INVALID_REQUEST,
	JSONRPC_METHOD_NOT_FOUND,
	JSONRPC_PARSE_ERROR,
	type Jsonrpc_Error_Code,
} from '$lib/jsonrpc.js';

// TODO maybe move some of this to `jsonrpc.ts` and extract the rest to `jsonrpc_helpers.ts`

/**
 * Extended JSON-RPC error codes with application-specific errors.
 */
export const JSONRPC_ERROR_CODES = {
	// Standard JSON-RPC errors
	PARSE_ERROR: JSONRPC_PARSE_ERROR,
	INVALID_REQUEST: JSONRPC_INVALID_REQUEST,
	METHOD_NOT_FOUND: JSONRPC_METHOD_NOT_FOUND,
	INVALID_PARAMS: JSONRPC_INVALID_PARAMS,
	INTERNAL_ERROR: JSONRPC_INTERNAL_ERROR,

	// TODO review/use these
	// Application-specific errors (-32000 to -32099)
	UNAUTHORIZED: -32001 as Jsonrpc_Error_Code,
	FORBIDDEN: -32002 as Jsonrpc_Error_Code,
	NOT_FOUND: -32003 as Jsonrpc_Error_Code,
	CONFLICT: -32004 as Jsonrpc_Error_Code,
	VALIDATION_ERROR: -32005 as Jsonrpc_Error_Code,
	RATE_LIMITED: -32006 as Jsonrpc_Error_Code,
	SERVICE_UNAVAILABLE: -32007 as Jsonrpc_Error_Code,
	TIMEOUT: -32008 as Jsonrpc_Error_Code,
	INSUFFICIENT_STORAGE: -32009 as Jsonrpc_Error_Code,
	// FILE_TOO_LARGE: -32010 as Jsonrpc_Error_Code,
	// UNSUPPORTED_MEDIA_TYPE: -32011 as Jsonrpc_Error_Code,

	// AI provider specific errors
	AI_PROVIDER_ERROR: -32020 as Jsonrpc_Error_Code,
	// AI_MODEL_NOT_FOUND: -32021 as Jsonrpc_Error_Code,
	// AI_QUOTA_EXCEEDED: -32022 as Jsonrpc_Error_Code,
	// AI_INVALID_REQUEST: -32023 as Jsonrpc_Error_Code,
} as const satisfies Record<string, Jsonrpc_Error_Code>;

/**
 * Maps HTTP status codes to JSON-RPC error codes.
 */
export const http_status_to_jsonrpc_code = (status: number): Jsonrpc_Error_Code => {
	switch (status) {
		case 400:
			return JSONRPC_ERROR_CODES.INVALID_PARAMS;
		case 401:
			return JSONRPC_ERROR_CODES.UNAUTHORIZED;
		case 403:
			return JSONRPC_ERROR_CODES.FORBIDDEN;
		case 404:
			return JSONRPC_ERROR_CODES.NOT_FOUND;
		case 409:
			return JSONRPC_ERROR_CODES.CONFLICT;
		case 422:
			return JSONRPC_ERROR_CODES.VALIDATION_ERROR;
		case 429:
			return JSONRPC_ERROR_CODES.RATE_LIMITED;
		case 500:
			return JSONRPC_ERROR_CODES.INTERNAL_ERROR;
		case 503:
			return JSONRPC_ERROR_CODES.SERVICE_UNAVAILABLE;
		case 504:
			return JSONRPC_ERROR_CODES.TIMEOUT;
		case 507:
			return JSONRPC_ERROR_CODES.INSUFFICIENT_STORAGE;
		default:
			return JSONRPC_ERROR_CODES.INTERNAL_ERROR;
	}
};

/**
 * Custom error class for JSON-RPC errors.
 */
export class Thrown_Jsonrpc_Error extends Error {
	code: Jsonrpc_Error_Code;
	data?: unknown;

	constructor(code: Jsonrpc_Error_Code, message: string, data?: unknown, options?: ErrorOptions) {
		super(message, options);
		this.code = code;
		this.data = data;
	}
}

// TODO we probably want `jsonrpc_error_messages` to replace a lot of code, but how to declare those and these but DRY?
export const jsonrpc_errors = {
	parse_error: (data?: unknown): Thrown_Jsonrpc_Error =>
		new Thrown_Jsonrpc_Error(JSONRPC_ERROR_CODES.PARSE_ERROR, 'parse error', data),

	invalid_request: (data?: unknown): Thrown_Jsonrpc_Error =>
		new Thrown_Jsonrpc_Error(JSONRPC_ERROR_CODES.INVALID_REQUEST, 'invalid request', data),

	method_not_found: (method: string, data?: unknown): Thrown_Jsonrpc_Error =>
		new Thrown_Jsonrpc_Error(
			JSONRPC_ERROR_CODES.METHOD_NOT_FOUND,
			`method not found: ${method}`,
			data,
		),

	invalid_params: (message: string, data?: unknown): Thrown_Jsonrpc_Error =>
		new Thrown_Jsonrpc_Error(JSONRPC_ERROR_CODES.INVALID_PARAMS, message, data),

	internal_error: (
		message: string = 'internal server error',
		data?: unknown,
	): Thrown_Jsonrpc_Error =>
		new Thrown_Jsonrpc_Error(JSONRPC_ERROR_CODES.INTERNAL_ERROR, message, data),

	unauthorized: (message: string = 'unauthorized', data?: unknown): Thrown_Jsonrpc_Error =>
		new Thrown_Jsonrpc_Error(JSONRPC_ERROR_CODES.UNAUTHORIZED, message, data),

	forbidden: (message: string = 'forbidden', data?: unknown): Thrown_Jsonrpc_Error =>
		new Thrown_Jsonrpc_Error(JSONRPC_ERROR_CODES.FORBIDDEN, message, data),

	not_found: (resource: string, data?: unknown): Thrown_Jsonrpc_Error =>
		new Thrown_Jsonrpc_Error(JSONRPC_ERROR_CODES.NOT_FOUND, `${resource} not found`, data),

	validation_error: (message: string, data?: unknown): Thrown_Jsonrpc_Error =>
		new Thrown_Jsonrpc_Error(JSONRPC_ERROR_CODES.VALIDATION_ERROR, message, data),

	service_unavailable_error: (message: string, data?: unknown): Thrown_Jsonrpc_Error =>
		new Thrown_Jsonrpc_Error(JSONRPC_ERROR_CODES.SERVICE_UNAVAILABLE, message, data),

	ai_provider_error: (provider: string, message: string, data?: unknown): Thrown_Jsonrpc_Error =>
		new Thrown_Jsonrpc_Error(
			JSONRPC_ERROR_CODES.AI_PROVIDER_ERROR,
			`${provider}: ${message}`,
			data,
		),
};
