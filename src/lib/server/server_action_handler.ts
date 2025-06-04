import type {Action_Input, Action_Output} from '$lib/action_types.js';
import type {Jsonrpc_Message_From_Client_To_Server} from '$lib/jsonrpc.js';
import type {Server_Action_Event} from '$lib/server/server_action_event.js';

// TODO @api improve these types

/**
 * Base server action handler with no authentication or authorization.
 */
export type Public_Server_Action_Handler<
	T_Input extends Action_Input = any,
	T_Output extends Action_Output = any,
	T_Message extends Jsonrpc_Message_From_Client_To_Server = Jsonrpc_Message_From_Client_To_Server,
> = (event: Server_Action_Event<T_Input, T_Output, T_Message>) => Promise<T_Output>;

/**
 * Server action handler with full authorization with a user/actor (including authentication).
 */
export type Authorized_Server_Action_Handler<
	T_Input extends Action_Input = any,
	T_Output extends Action_Output = any,
	T_Message extends Jsonrpc_Message_From_Client_To_Server = Jsonrpc_Message_From_Client_To_Server,
> = (event: Server_Action_Event<T_Input, T_Output, T_Message>) => Promise<T_Output>;

/**
 * Union type for all service types.
 * Server action handlers return values or throw errors (see `Jsonrpc_Error`).
 */
export type Server_Action_Handler<
	T_Input extends Action_Input = any,
	T_Output extends Action_Output = any,
	T_Message extends Jsonrpc_Message_From_Client_To_Server = Jsonrpc_Message_From_Client_To_Server,
> =
	| Public_Server_Action_Handler<T_Input, T_Output, T_Message>
	| Authorized_Server_Action_Handler<T_Input, T_Output, T_Message>;
