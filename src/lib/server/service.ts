import type {Logger} from '@ryanatkn/belt/log.js';
import type {z} from 'zod';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Request_Response_Action_Spec} from '$lib/action_spec.js';
import {Api_Error, is_http_status_ok, type Api_Result, type Http_Status} from '$lib/api.js';
import {stringify_zod_error} from '$lib/zod_helpers.js';

/**
 * Return type for services.
 */
export interface Service_Return<T_Value = any> {
	status?: Http_Status;
	value: T_Value;
}

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
	// TODO hacky check here
	if (result.status == null || is_http_status_ok(result.status)) {
		return {
			ok: true,
			status: result.status ?? 200,
			value: result.value,
		};
	} else {
		return {
			ok: false,
			status: result.status,
			message: result.value as string, // TODO hack, needs better error handling
		};
	}
};

export const validate_service_params = <T_Action_Spec extends Request_Response_Action_Spec>(
	spec: T_Action_Spec,
	params: unknown,
	log?: Logger | null,
): z.infer<T_Action_Spec['params']> => {
	const parsed = spec.params.safeParse(params);
	if (!parsed.success) {
		log?.error('failed to validate service params', spec.method, params, parsed.error.issues);
		throw new Api_Error(
			400,
			`invalid params to ${spec.method}: ${stringify_zod_error(parsed.error)}`,
		);
	}
	return parsed.data;
};

export const validate_service_response_params = <
	T_Action_Spec extends Request_Response_Action_Spec,
>(
	spec: T_Action_Spec,
	response_params: unknown,
	log?: Logger | null,
): z.infer<T_Action_Spec['response_params']> => {
	const parsed = spec.response_params.safeParse(response_params);
	if (!parsed.success) {
		log?.error(
			'failed to validate service response params',
			spec.method,
			response_params,
			parsed.error.issues,
		);
		throw new Api_Error(
			500,
			`service response validation failed for ${spec.method}: ${stringify_zod_error(parsed.error)}`,
		);
	}
	return parsed.data;
};
