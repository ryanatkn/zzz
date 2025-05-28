import type {Action_Method} from '$lib/action_metatypes.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import type {Api_Request_Response_Flag} from '$lib/api.js';
import type {Jsonrpc_Notification, Jsonrpc_Request} from '$lib/jsonrpc.js';
import type {Action_Message_Union} from '$lib/action_collections.js';

/**
 * Client-side mutation system for handling action responses.
 * Client_Action_Handlers are synchronous functions that apply state changes to the client app
 * based on action requests or responses.
 */

/**
 * Context provided to mutation handlers.
 */
export interface Client_Action_Context<
	T_App extends Zzz = Zzz,
	T_Params = unknown,
	T_Result = any,
> {
	zzz: T_App;
	/** JSON-RPC method for the action. Maps to two types for request_response actions. */
	method: Action_Method;
	params: T_Params;
	result: T_Result;
	// TODO refactor
	request_response_flag: Api_Request_Response_Flag;
	action_message: Action_Message_Union;
	// TODO need to correctly handle request/response messages, and others if they're not here
	jsonrpc_message: Jsonrpc_Request | Jsonrpc_Notification | null;
	/** Adds a callback hook that runs after mutation finishes. */
	after_client_action: After_Client_Action | undefined;
}

/**
 * Must be synchronous.
 */
export type Client_Action_Handler<T_App extends Zzz = Zzz, T_Params = any, T_Result = any> = (
	ctx: Client_Action_Context<T_App, T_Params, T_Result>,
) => any;

/**
 * Type for registering callbacks to run after mutation completes.
 */
export type After_Client_Action = (cb: After_Client_Action_Callback) => void;

/**
 * Callback function type for after mutation hooks.
 */
export type After_Client_Action_Callback = () => void | Promise<void>;

// TODO BLOCK @api make this a class where flush is a private method
/**
 * Creates a mutation context with the provided parameters and
 * a function to flush after-mutation callbacks.
 */
export const create_mutation_context = <
	T_App extends Zzz = Zzz,
	T_Params = unknown,
	T_Result = any,
>(
	zzz: T_App,
	method: Action_Method,
	params: T_Params,
	result: T_Result,
	request_response_flag: Api_Request_Response_Flag,
	action_message: Action_Message_Union,
	jsonrpc_message: Jsonrpc_Request | Jsonrpc_Notification | null,
): {
	ctx: Client_Action_Context<T_App, T_Params, T_Result>;
	flush_after_client_action: () => Promise<void>;
} => {
	const cbs: Array<After_Client_Action_Callback> = [];

	const after_client_action: After_Client_Action = (cb) => {
		cbs.push(cb);
	};

	const flush_after_client_action = async (): Promise<void> => {
		for (const cb of cbs) {
			await cb(); // eslint-disable-line no-await-in-loop
		}
	};

	const ctx = {
		zzz,
		method,
		params,
		result,
		request_response_flag,
		action_message,
		jsonrpc_message,
		after_client_action,
	} satisfies Client_Action_Context<T_App, T_Params, T_Result>;

	return {ctx, flush_after_client_action};
};
