import type {Api_Result} from '$lib/api.js';
import type {Action_Spec} from '$lib/schemas.js';

export interface Api_Client<
	T_Params_Map extends Record<string, any> = any, // TODO default and value types?
	T_Result_Map extends Record<string, any> = any, // TODO default and value types?
> {
	find: (name: string) => Action_Spec | undefined; // TODO custom action types
	invoke: <T_Service_Name extends string, T_Params extends T_Params_Map[T_Service_Name]>(
		name: T_Service_Name,
		params: T_Params,
	) => Promise<Api_Result<T_Result_Map[T_Service_Name]>>;
	close: () => void;
}
