import type {Action_Method} from '$lib/action_metatypes.js';
import type {Zzz_App} from '$lib/zzz_app.svelte.js';
import type {Action_Input, Action_Output, Action_Phase} from '$lib/action_types.js';
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
export class Client_Action_Event<
	T_App extends Zzz_App = Zzz_App,
	T_Input extends Action_Input = any, // TODO @api type
	T_Output extends Action_Output = any, // TODO @api type
	T_Message extends Jsonrpc_Singular_Message | null = Jsonrpc_Singular_Message | null,
> {
	app: T_App;
	/** JSON-RPC method for the action. */
	method: Action_Method;
	/** The phase of the action handling event/context. */
	phase: Action_Phase;
	input: T_Input;
	output: T_Output;
	/** The JSON-RPC message associated with this action */
	jsonrpc_message: T_Message;

	#cbs: Array<After_Client_Action_Callback> = [];

	handled: boolean = false;

	constructor(
		app: T_App,
		method: Action_Method,
		phase: Action_Phase,
		input: T_Input,
		output: T_Output,
		jsonrpc_message: T_Message,
	) {
		this.app = app;
		this.method = method;
		this.phase = phase;
		// TODO BLOCK @api should these be input/output instead of params/result?
		this.input = input;
		this.output = output;
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
			throw new Error('Client_Action_Event has already been handled');
		}
		this.handled = true;

		this.output = handler(this);

		void this.#flush_after_client_action(); // not awaited because these are side effects, also supports sync functions
	}
}
