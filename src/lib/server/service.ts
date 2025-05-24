// src/lib/server/service.ts

import type {Zzz_Server} from '$lib/server/zzz_server.js';

/**
 * Return type for services.
 * Wraps the value to allow for future metadata additions.
 */
export interface Service_Return<T_Value = any> {
	value: T_Value;
	// Future fields can be added here (e.g., metadata, warnings, side effects, etc.)
}

/**
 * Base service interface with no authentication.
 * Services return values wrapped in Service_Return or throw Jsonrpc_Error.
 */
export interface Nonauthenticated_Service<T_Params extends object | null = any, T_Value = any> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<Service_Return<T_Value>>;
}

/**
 * Service interface with authentication but no authorization.
 * Services return values wrapped in Service_Return or throw Jsonrpc_Error.
 */
export interface Nonauthorized_Service<T_Params extends object | null = any, T_Value = any> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<Service_Return<T_Value>>;
}

/**
 * Service interface with full authorization (including authentication).
 * Services return values wrapped in Service_Return or throw Jsonrpc_Error.
 */
export interface Authorized_Service<T_Params extends object | null = any, T_Value = any> {
	perform: (params: T_Params, server: Zzz_Server) => Promise<Service_Return<T_Value>>;
}

/**
 * Union type for all service types.
 */
export type Service<T_Params extends object | null = any, T_Value = any> =
	| Nonauthenticated_Service<T_Params, T_Value>
	| Nonauthorized_Service<T_Params, T_Value>
	| Authorized_Service<T_Params, T_Value>;
