import type {Zzz_App} from '$lib/zzz.svelte.js';
import type {Client_Action_Context} from '$lib/client_action_event.js';

/**
 * `Client_Action_Handler`s are synchronous functions that apply state changes to the client app
 * based on action messages - requests, responses, notifications, and calls.
 */
export type Client_Action_Handler<
	T_App extends Zzz_App = Zzz_App,
	T_Params = any,
	T_Result = any,
> = (ctx: Client_Action_Context<T_App, T_Params, T_Result>) => T_Result | Promise<T_Result>; // TODO BLOCK @api return type - include the promise?
