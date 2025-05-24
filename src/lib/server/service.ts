import type {Zzz_Server} from '$lib/server/zzz_server.js';
import {
	API_RESULT_UNKNOWN_ERROR,
	is_http_status_ok,
	type Api_Result,
	type Error_Response,
	type Http_Status,
} from '$lib/api.js';

// TODO rename from service to something else, probably --
// actions have mutations on the client,
// on the server they're currently called services,
// but they're basically just handlers

/**
 * Return type for services.
 */
export type Service_Return<T_Value = any> =
	| Service_Return_Success<T_Value>
	| Service_Return_Failure;

export interface Service_Return_Success<T_Value = any> {
	/**
	 * This is slightly tricky bc it's optional for ergonomics but I think it's good.
	 *
	 * @default true
	 */
	ok?: true | undefined; //
	/** @default 200 */
	status?: Http_Status; // TODO BLOCK @api need to use JSON-RPC error codes instead, probably remove the wrappers of `Api_Result`
	value: T_Value;
}
export interface Service_Return_Failure extends Error_Response {
	ok: false;
	status?: Http_Status;
}

export const is_service_return_success = (
	result: Service_Return,
): result is Service_Return_Success => result.ok !== false;

/**
 * Base service interface with no authentication.
 */
export interface Nonauthenticated_Service<
	T_Params extends object | null = any,
	T_Returned extends Service_Return = Service_Return,
> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<T_Returned>;
}

/**
 * Service interface with authentication but no authorization.
 */
export interface Nonauthorized_Service<
	T_Params extends object | null = any,
	T_Returned extends Service_Return = Service_Return,
> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<T_Returned>;
}

/**
 * Service interface with full authorization. (including authentication)
 */
export interface Authorized_Service<
	T_Params extends object | null = any,
	T_Returned extends Service_Return = Service_Return,
> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<T_Returned>;
}

/**
 * Converts a service result to a standard API result.
 */
export const service_return_to_api_result = <T_Value>(
	result: Service_Return<T_Value>,
): Api_Result<T_Value> => {
	if (is_service_return_success(result)) {
		// validate the status for the expected success
		if (result.status && !is_http_status_ok(result.status)) {
			return API_RESULT_UNKNOWN_ERROR;
		}
		return {
			ok: true,
			status: result.status ?? 200,
			value: result.value,
		};
	} else {
		// validate the status for the expected failure
		if (result.status && is_http_status_ok(result.status)) {
			return API_RESULT_UNKNOWN_ERROR;
		}
		return {
			ok: false,
			status: result.status ?? 500,
			// TODO hack, needs better error handling
			message:
				typeof result.message === 'string' ? result.message : API_RESULT_UNKNOWN_ERROR.message,
		};
	}
};
