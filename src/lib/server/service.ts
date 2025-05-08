import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Action_Client, Action_Server, Service_Action_Spec} from '$lib/schemas.js';
import {Api_Error, type Http_Status, type Successful_Api_Result} from '$lib/api.js';
import type {Logger} from '@ryanatkn/belt/log.js';

/**
 * Return type for services.
 */
export interface Service_Return<T_Value = any> {
	status?: Http_Status;
	value: T_Value;
}

/**
 * Base service interface with no authentication
 */
export interface Non_Authenticated_Service<
	T_Params extends object | null = any,
	T_Returned extends Service_Return = Service_Return,
> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<T_Returned>;
}

/**
 * Service interface with authentication but no authorization
 */
export interface Non_Authorized_Service<
	T_Params extends object | null = any,
	T_Returned extends Service_Return = Service_Return,
> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<T_Returned>;
}

/**
 * Service interface with full authorization
 */
export interface Authorized_Service<
	T_Params extends object | null = any,
	T_Returned extends Service_Return = Service_Return,
> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<T_Returned>;
}

/**
 * Maps action types to service handlers
 */
export type Service_Map = Map<
	string,
	(message: Action_Client, server: Zzz_Server) => Promise<Action_Server | null>
>;

/**
 * Helper function to convert a service result to a standard API result.
 */
export const service_return_to_api_result = <T_Value>(
	result: Service_Return<T_Value>,
): Successful_Api_Result<T_Value> => ({
	ok: true,
	status: result.status ?? 200,
	value: result.value,
});

export const validate_service_params = (
	action: Service_Action_Spec,
	params: any,
	log?: Logger,
): void => {
	const parsed = action.params.safeParse(params);
	if (!parsed.success) {
		log?.error('failed to validate service params', action.name, params, parsed.error.issues);
		throw new Api_Error(400, `invalid params to ${action.name}: ${parsed.error.issues[0].message}`); // TODO @many handle multiple errors instead of just the first
	}
};

export const validate_service_response = (
	action: Service_Action_Spec,
	response: any,
	log?: Logger,
): void => {
	const parsed = action.response.safeParse(response);
	if (!parsed.success) {
		log?.error('failed to validate service response', action.name, response, parsed.error.issues);
		throw Error(
			`service response validation failed for ${action.name}: ${parsed.error.issues[0].message}`,
		); // TODO @many handle multiple errors instead of just the first
	}
};
