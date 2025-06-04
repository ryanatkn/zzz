import type {Zzz_App} from '$lib/zzz_app.svelte.js';
import type {Client_Action_Context} from '$lib/client_action_event.js';

/**
 * `Client_Action_Handler`s are synchronous functions that apply state changes to the client app
 * based on action messages - requests, responses, notifications, and calls.
 */
export type Client_Action_Handler<
	T_App extends Zzz_App = Zzz_App,
	T_Input = any,
	T_Output = any,
	T_Returned = any,
> = (ctx: Client_Action_Context<T_App, T_Input, T_Output>) => T_Returned;
