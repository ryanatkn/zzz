import type {Action_Method} from '$lib/action_metatypes.js';
import type {Zzz_App} from '$lib/zzz.svelte.js';
import type {Action_Request_Response_Flag} from '$lib/action_types.js';
import type {Jsonrpc_Notification, Jsonrpc_Request} from '$lib/jsonrpc.js';
import type {Action_Message_Union} from '$lib/action_collections.js';

/**
 * Client-side mutation system for handling action responses.
 * Client_Action_Handlers are synchronous functions that apply state changes to the client app
 * based on action requests or responses.
 */

/**
 * Must be synchronous.
 */
export type Client_Action_Handler<
	T_App extends Zzz_App = Zzz_App,
	T_Params = any,
	T_Result = any,
> = (ctx: Client_Action_Context<T_App, T_Params, T_Result>) => any;

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
export class Client_Action_Context<
	T_App extends Zzz_App = Zzz_App,
	T_Params = unknown,
	T_Result = any,
> {
	app: T_App;
	/** JSON-RPC method for the action. Maps to two types for request_response actions. */
	method: Action_Method;
	params: T_Params;
	result: T_Result;
	// TODO refactor
	request_response_flag: Action_Request_Response_Flag;
	action_message: Action_Message_Union;
	// TODO need to correctly handle request/response messages, and others if they're not here
	jsonrpc_message: Jsonrpc_Request | Jsonrpc_Notification | null;

	#cbs: Array<After_Client_Action_Callback> = [];

	// TODO BLOCK should this be multi-phase? or separate events for req/res?
	handled: boolean = false;

	constructor(
		app: T_App,
		method: Action_Method,
		params: T_Params,
		result: T_Result,
		request_response_flag: Action_Request_Response_Flag,
		action_message: Action_Message_Union,
		jsonrpc_message: Jsonrpc_Request | Jsonrpc_Notification | null,
	) {
		this.app = app;
		this.method = method;
		// TODO BLOCK @api should these be input/output instead of params/result?
		this.params = params;
		this.result = result;
		this.request_response_flag = request_response_flag;
		this.action_message = action_message;
		this.jsonrpc_message = jsonrpc_message;
	}

	async #flush_after_client_action(): Promise<void> {
		for (const cb of this.#cbs) {
			await cb(); // eslint-disable-line no-await-in-loop
		}
	}

	/** Adds a callback hook that runs after mutation finishes. */
	after_client_action: After_Client_Action = (cb) => {
		this.#cbs.push(cb);
	};

	handle(handler: Client_Action_Handler): void {
		if (this.handled) {
			throw new Error('Server_Action_Event has already been handled');
		}
		this.handled = true;

		this.result = handler(this);

		void this.#flush_after_client_action(); // not awaited because these are side effects, also supports sync functions
	}
}
