import type {Zzz_App} from '$lib/zzz_app.svelte.js';
import type {Client_Action_Event} from '$lib/client_action_event.js';
import type {Action_Input, Action_Output} from '$lib/action_types.js';
import type {
	Jsonrpc_Notification,
	Jsonrpc_Response_Or_Error,
	Jsonrpc_Request,
} from '$lib/jsonrpc.js';

/**
 * `Client_Action_Handler`s are synchronous functions that apply state changes to the client app
 * based on action messages - requests, responses, notifications, and calls.
 */
export type Client_Action_Handler<
	T_App extends Zzz_App = Zzz_App,
	T_Input extends Action_Input = any, // TODO @api type
	T_Output extends Action_Output = any, // TODO @api type
	T_Returned = any,
	T_Request_Message extends Jsonrpc_Request | undefined = Jsonrpc_Request | undefined,
	T_Response_Message extends Jsonrpc_Response_Or_Error | undefined =
		| Jsonrpc_Response_Or_Error
		| undefined,
	T_Notification_Message extends Jsonrpc_Notification | undefined =
		| Jsonrpc_Notification
		| undefined,
> = (
	ctx: Client_Action_Event<
		T_App,
		T_Input,
		T_Output,
		T_Request_Message,
		T_Response_Message,
		T_Notification_Message
	>,
) => T_Returned;
