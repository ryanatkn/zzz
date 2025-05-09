import type {Logger} from '@ryanatkn/belt/log.js';
import type {z} from 'zod';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Service_Action_Spec} from '$lib/schemas.js';
import type {Action_Client, Action_Server} from '$lib/action_collections.js';
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
export interface Non_Authenticated_Service<
	T_Params extends object | null = any,
	T_Returned extends Service_Return = Service_Return,
> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<T_Returned>;
}

/**
 * Service interface with authentication but no authorization.
 */
export interface Non_Authorized_Service<
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
 * Maps action types to service handlers.
 */
export type Service_Map = Map<
	string,
	(message: Action_Client, server: Zzz_Server) => Promise<Action_Server | null>
>;

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

export const validate_service_params = (
	spec: Service_Action_Spec,
	params: unknown,
	log?: Logger | null,
	// TODO BLOCK this return type needs to be based on the `Service_Action_Spec` type, maybe using a typed `name` instead of the `spec`?
): z.infer<Service_Action_Spec['params']> => {
	const parsed = spec.params.safeParse(params === undefined ? null : params);
	if (!parsed.success) {
		log?.error('failed to validate service params', spec.name, params, parsed.error.issues);
		throw new Api_Error(
			400,
			`invalid params to ${spec.name}: ${stringify_zod_error(parsed.error)}`,
		); // TODO @many handle multiple errors instead of just the first
	}
	return parsed.data;
};

export const validate_service_response = (
	action: Service_Action_Spec,
	response: unknown,
	log?: Logger | null,
	// TODO BLOCK this return type needs to be based on the `Service_Action_Spec` type, maybe using a typed `name` instead of the `spec`?
): z.infer<Service_Action_Spec['response']> => {
	const parsed = action.response.safeParse(response);
	if (!parsed.success) {
		log?.error('failed to validate service response', action.name, response, parsed.error.issues);
		throw new Api_Error(
			500,
			`service response validation failed for ${action.name}: ${stringify_zod_error(parsed.error)}`, // TODO @many handle multiple errors instead of just the first
		);
	}
	return parsed.data;
};
