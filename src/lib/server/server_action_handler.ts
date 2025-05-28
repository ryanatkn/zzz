import type {Action_Message_Base} from '$lib/action_types.js';
import type {Jsonrpc_Params} from '$lib/jsonrpc.js';
import type {Zzz_Server} from '$lib/server/zzz_server.js';

// TODO BLOCK @api think about send/receive and then request/response? `phase`?

// TODO think about the `event` name, could be `ctx` or `context` or `action_event` or `action_context`

/**
 * Base server action handler with no authentication or authorization.
 */
export type Public_Server_Action_Handler<
	T_Params extends Jsonrpc_Params = any,
	T_Result = any,
	T_Message extends Action_Message_Base = any,
> = (event: {params: T_Params; message: T_Message; server: Zzz_Server}) => Promise<T_Result>;

/**
 * Server action handler with authentication but no authorization (no user/actor context).
 */
export type Authenticated_Server_Action_Handler<
	T_Params extends Jsonrpc_Params = any,
	T_Result = any,
	T_Message extends Action_Message_Base = any,
> = (event: {params: T_Params; message: T_Message; server: Zzz_Server}) => Promise<T_Result>;

/**
 * Server action handler with full authorization with a user/actor (including authentication).
 */
export type Authorized_Server_Action_Handler<
	T_Params extends Jsonrpc_Params = any,
	T_Result = any,
	T_Message extends Action_Message_Base = any,
> = (event: {params: T_Params; message: T_Message; server: Zzz_Server}) => Promise<T_Result>;

/**
 * Union type for all service types.
 * Server action handlers return values or throw errors (see `Jsonrpc_Error`).
 */
export type Server_Action_Handler<
	T_Params extends Jsonrpc_Params = any,
	T_Result = any,
	T_Message extends Action_Message_Base = any,
> =
	| Public_Server_Action_Handler<T_Params, T_Result, T_Message>
	| Authenticated_Server_Action_Handler<T_Params, T_Result, T_Message>
	| Authorized_Server_Action_Handler<T_Params, T_Result, T_Message>;
