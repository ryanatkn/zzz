// src/lib/server/service.ts

import type {Zzz_Server} from '$lib/server/zzz_server.js';

/**
 * Base service interface with no authentication.
 */
export interface Nonauthenticated_Service<T_Params extends object | null = any, T_Value = any> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<T_Value>;
}

/**
 * Service interface with authentication but no authorization.
 */
export interface Nonauthorized_Service<T_Params extends object | null = any, T_Value = any> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<T_Value>;
}

/**
 * Service interface with full authorization (including authentication).
 */
export interface Authorized_Service<T_Params extends object | null = any, T_Value = any> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<T_Value>;
}

/**
 * Union type for all service types.
 * Services return values or throw errors, wiith`Jsonrpc_Error`.
 */
export type Service<T_Params extends object | null = any, T_Value = any> =
	| Nonauthenticated_Service<T_Params, T_Value>
	| Nonauthorized_Service<T_Params, T_Value>
	| Authorized_Service<T_Params, T_Value>;
