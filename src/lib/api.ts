import {Result_Error, type Result} from '@ryanatkn/belt/result.js';
import type {Flavored} from '@ryanatkn/belt/types.js';
import type {ContentfulStatusCode} from 'hono/utils/http-status';
import {z} from 'zod';

import {JSONRPCNotificationParams, JSONRPCRequestParams} from '$lib/jsonrpc.js';

export const Http_Status = z.number().int();
export type Http_Status = ContentfulStatusCode;

export const is_http_status_ok = (status: Http_Status): boolean => status < 300; // TODO maybe >= 200? idk, informational responses -- are they ok??

export const Http_Method = z.enum([
	'CONNECT',
	'DELETE',
	'GET',
	'HEAD',
	'OPTIONS',
	'PATCH',
	'POST',
	'PUT',
	'TRACE',
]);
export type Http_Method = z.infer<typeof Http_Method>;

/** The JSON-RPC `params` types. */
export const Api_Params = z.union([JSONRPCRequestParams, JSONRPCNotificationParams, z.void()]);
export type Api_Params = z.infer<typeof Api_Params>;

export interface Error_Response {
	message: string;
}

export const ERROR_MESSAGE_UNKNOWN = Result_Error.DEFAULT_MESSAGE;

export type Api_Result<T_Value = any> = Result<
	{status: Http_Status; value: T_Value},
	{status: Http_Status} & Error_Response
>;

export const API_RESULT_UNKNOWN_ERROR = {
	ok: false as const,
	status: 500 as const,
	message: 'unknown error',
};

export interface Successful_Api_Result<T_Value = any> {
	ok: true;
	status: Http_Status;
	value: T_Value;
}

export interface Failed_Api_Result {
	ok: false;
	status: Http_Status;
	message: string;
}

/**
 * Converts an `Error` object that may or may not
 * be an `Api_Error` or `Result_Error` to a failed `Api_Result`.
 * The purpose is to enable throwing errors that specify
 * a `status` and user-facing error `message`.
 * @param err - Any `Error`, may or may not be an `Api_Error` or `Result_Error`.
 * @returns An `Api_Result` with `ok: false`.
 */
export const to_failed_api_result = (err: any): Failed_Api_Result =>
	err instanceof Api_Error
		? {ok: false, status: err.status, message: err.message}
		: err instanceof Result_Error
			? {ok: false, status: (err.result as any).status || 500, message: err.message}
			: {ok: false, status: 500, message: ERROR_MESSAGE_UNKNOWN}; // // safe generic fallback

export type Api_Error_Name = Flavored<string, 'Api_Error_Name'>;
export type Api_Error_Message = Flavored<string, 'Api_Error_Message'>;

export class Api_Error extends Error {
	status: Http_Status;

	constructor(status: Http_Status, message: Api_Error_Message) {
		super(message);
		this.status = status;
	}
}

export type Api_Errors = Record<Api_Error_Name, [Http_Status, Api_Error_Message]>;

// TODO BLOCK this doesn't use the `api_errors.ts` module pattern because it's for checks,
// so it doesn't have the same i18n and status code API - maybe remove this with Zod schema parsing errors?
export const assert_api_error = (
	error_message: Api_Error_Message | null,
	status: Http_Status = 400,
): void => {
	if (error_message) throw new Api_Error(status, error_message);
};

/**
 * Provides an ergnomic way to throw extensible `Api_Error`s without polluting the callstack.
 *
 * @example
 * ```
 * const api_error = create_api_errors({FAILED_BECAUSE_WHY: [400, 'failed because why']});
 * throw new api_error.FAILED_BECAUSE_WHY();
 * ```
 */
export const create_api_errors = <T extends Api_Errors>(
	api_errors: T,
): Record<keyof T, new () => Api_Error> =>
	new Proxy(Object.create(null), {
		get: (_target, name: any) => {
			// TODO cache ?
			return class extends Api_Error {
				constructor() {
					const [status, message] = api_errors[name];
					super(status, message);
				}
			};
		},
	});

export type Api_Request_Response_Flag = 'request' | 'response' | null;
