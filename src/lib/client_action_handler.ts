import type {Zzz_App} from '$lib/zzz_app.svelte.js';
import type {Client_Action_Event} from '$lib/client_action_event.js';
import type {Action_Input, Action_Output} from '$lib/action_types.js';
import type {Jsonrpc_Singular_Message} from '$lib/jsonrpc.js';

/**
 * `Client_Action_Handler`s are synchronous functions that apply state changes to the client app
 * based on action messages - requests, responses, notifications, and calls.
 */
export type Client_Action_Handler<
	T_App extends Zzz_App = Zzz_App,
	T_Input extends Action_Input = any, // TODO @api type
	T_Output extends Action_Output = any, // TODO @api type
	T_Returned = any,
	T_Message extends Jsonrpc_Singular_Message | null = Jsonrpc_Singular_Message | null,
> = (ctx: Client_Action_Event<T_App, T_Input, T_Output, T_Message>) => T_Returned;
