import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Action_Client, Action_Server} from '$lib/schemas.js';
import type {Http_Status, Successful_Api_Result} from '$lib/api.js';

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
