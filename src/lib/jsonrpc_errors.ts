// @slop

import type {JSONRPCErrorCode} from '$lib/jsonrpc.js';
import {z} from 'zod';

// TODO is messy but gets more type safety
/**
 * Extended JSON-RPC error codes for Zzz application.
 * Standard codes: -32768 to -32000
 * Application codes: -32000 to -32099
 */
export const JSONRPC_ERROR_CODES = {
	// Standard JSON-RPC errors
	PARSE_ERROR: -32700 as Jsonrpc_Error_Code,
	INVALID_REQUEST: -32600 as Jsonrpc_Error_Code,
	METHOD_NOT_FOUND: -32601 as Jsonrpc_Error_Code,
	INVALID_PARAMS: -32602 as Jsonrpc_Error_Code,
	INTERNAL_ERROR: -32603 as Jsonrpc_Error_Code,

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
	FILE_TOO_LARGE: -32010 as Jsonrpc_Error_Code,
	UNSUPPORTED_MEDIA_TYPE: -32011 as Jsonrpc_Error_Code,

	// AI provider specific errors
	AI_PROVIDER_ERROR: -32020 as Jsonrpc_Error_Code,
	AI_MODEL_NOT_FOUND: -32021 as Jsonrpc_Error_Code,
	AI_QUOTA_EXCEEDED: -32022 as Jsonrpc_Error_Code,
	AI_INVALID_REQUEST: -32023 as Jsonrpc_Error_Code,
} as const satisfies Record<string, Jsonrpc_Error_Code>;

// TODO BLOCK @api move this to the jsonrpc.ts module (and probably rename all to use this convention)
export const Jsonrpc_Error_Code = z.number().brand('Jsonrpc_Error_Code');
export type Jsonrpc_Error_Code = z.infer<typeof Jsonrpc_Error_Code>;

/**
 * Maps HTTP status codes to JSON-RPC error codes.
 * Used during migration period.
 */
export const http_status_to_jsonrpc_code = (status: number): JSONRPCErrorCode => {
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
 * Replaces Api_Error.
 */
export class Jsonrpc_Error extends Error {
	code: JSONRPCErrorCode;
	data?: unknown;

	constructor(code: JSONRPCErrorCode, message: string, data?: unknown) {
		super(message);
		this.code = code;
		this.data = data;
		this.name = 'JsonrpcError';
	}
}

/**
 * Helper to create common JSON-RPC errors.
 */
export const jsonrpc_errors = {
	parse_error: (data?: unknown): Jsonrpc_Error =>
		new Jsonrpc_Error(JSONRPC_ERROR_CODES.PARSE_ERROR, 'Parse error', data),

	invalid_request: (data?: unknown): Jsonrpc_Error =>
		new Jsonrpc_Error(JSONRPC_ERROR_CODES.INVALID_REQUEST, 'Invalid request', data),

	method_not_found: (method: string): Jsonrpc_Error =>
		new Jsonrpc_Error(JSONRPC_ERROR_CODES.METHOD_NOT_FOUND, `Method not found: ${method}`),

	invalid_params: (message: string, data?: unknown): Jsonrpc_Error =>
		new Jsonrpc_Error(JSONRPC_ERROR_CODES.INVALID_PARAMS, message, data),

	internal_error: (message: string = 'Internal server error', data?: unknown): Jsonrpc_Error =>
		new Jsonrpc_Error(JSONRPC_ERROR_CODES.INTERNAL_ERROR, message, data),

	unauthorized: (message: string = 'Unauthorized'): Jsonrpc_Error =>
		new Jsonrpc_Error(JSONRPC_ERROR_CODES.UNAUTHORIZED, message),

	forbidden: (message: string = 'Forbidden'): Jsonrpc_Error =>
		new Jsonrpc_Error(JSONRPC_ERROR_CODES.FORBIDDEN, message),

	not_found: (resource: string): Jsonrpc_Error =>
		new Jsonrpc_Error(JSONRPC_ERROR_CODES.NOT_FOUND, `${resource} not found`),

	validation_error: (message: string, data?: unknown): Jsonrpc_Error =>
		new Jsonrpc_Error(JSONRPC_ERROR_CODES.VALIDATION_ERROR, message, data),

	ai_provider_error: (provider: string, message: string, data?: unknown): Jsonrpc_Error =>
		new Jsonrpc_Error(JSONRPC_ERROR_CODES.AI_PROVIDER_ERROR, `${provider}: ${message}`, data),
};
