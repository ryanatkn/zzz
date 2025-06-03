import type {Jsonrpc_Message_From_Client_To_Server} from '$lib/jsonrpc.js';
import type {Server_Action_Event} from '$lib/server/server_action_event.js';

// TODO BLOCK @api think about send/receive and then request/response? `phase`?

// TODO think about the `event` name, could be `ctx` or `context` or `action_event` or `action_context`

/**
 * Base server action handler with no authentication or authorization.
 */
export type Public_Server_Action_Handler<
	T_Input = any,
	T_Output = any,
	T_Message extends Jsonrpc_Message_From_Client_To_Server = any,
> = (event: Server_Action_Event<T_Input, T_Output, T_Message>) => Promise<T_Output>;

/**
 * Server action handler with full authorization with a user/actor (including authentication).
 */
export type Authorized_Server_Action_Handler<
	T_Input = any,
	T_Output = any,
	T_Message extends Jsonrpc_Message_From_Client_To_Server = any,
> = (event: Server_Action_Event<T_Input, T_Output, T_Message>) => Promise<T_Output>;

/**
 * Union type for all service types.
 * Server action handlers return values or throw errors (see `Jsonrpc_Error`).
 */
export type Server_Action_Handler<
	T_Input = any,
	T_Output = any,
	T_Message extends Jsonrpc_Message_From_Client_To_Server = any,
> =
	| Public_Server_Action_Handler<T_Input, T_Output, T_Message>
	| Authorized_Server_Action_Handler<T_Input, T_Output, T_Message>;
