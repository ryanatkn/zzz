import type {Action_Method} from '$lib/action_metatypes.js';
import type {Zzz_App} from '$lib/zzz.svelte.js';
import type {Action_Request_Response_Flag} from '$lib/action_types.js';
import type {Jsonrpc_Singular_Message} from '$lib/jsonrpc.js';
import type {Client_Action_Handler} from '$lib/client_action_handler.js';

/**
 * Type for registering callbacks to run after mutation completes.
 */
export type After_Client_Action = (cb: After_Client_Action_Callback) => void;

/**
 * Callback function type for after mutation hooks.
 */
export type After_Client_Action_Callback = () => void | Promise<void>;

/**
 * Context object passed to client action handlers.
 * Provides access to the app, action details, and results.
 */
export class Client_Action_Context<
	T_App extends Zzz_App = Zzz_App,
	T_Params = unknown,
	T_Result = any,
> {
	app: T_App;
	/** JSON-RPC method for the action. */
	method: Action_Method;
	params: T_Params;
	result: T_Result;
	// TODO BLOCK @api @many action messages should be removed, instead tracked inside an action
	request_response_flag: Action_Request_Response_Flag;
	/** The JSON-RPC message associated with this action */
	jsonrpc_message: Jsonrpc_Singular_Message | null;

	#cbs: Array<After_Client_Action_Callback> = [];

	// TODO BLOCK should this be multi-phase? or separate events for req/res? refactored with `Action`?
	handled: boolean = false;

	constructor(
		app: T_App,
		method: Action_Method,
		params: T_Params,
		result: T_Result,
		request_response_flag: Action_Request_Response_Flag,
		jsonrpc_message: Jsonrpc_Singular_Message | null,
	) {
		this.app = app;
		this.method = method;
		// TODO BLOCK @api should these be input/output instead of params/result?
		this.params = params;
		this.result = result;
		this.request_response_flag = request_response_flag;
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
			throw new Error('Client_Action_Context has already been handled');
		}
		this.handled = true;

		this.result = handler(this);

		void this.#flush_after_client_action(); // not awaited because these are side effects, also supports sync functions
	}
}
