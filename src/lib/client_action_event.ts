import type {Logger} from '@ryanatkn/belt/log.js';

import type {Action_Method, Actions_Api} from '$lib/action_metatypes.js';
import type {Zzz_App} from '$lib/zzz_app.svelte.js';
import type {Action_Input, Action_Output, Action_Phase} from '$lib/action_types.js';
import type {Jsonrpc_Response_Or_Error, Jsonrpc_Singular_Message} from '$lib/jsonrpc.js';

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
	T_Response_Message extends Jsonrpc_Response_Or_Error | undefined =
		| Jsonrpc_Response_Or_Error
		| undefined,
> {
	app: T_App;
	/** JSON-RPC method for the action. */
	method: Action_Method;
	/** The phase of the action handling event/context. */
	phase: Action_Phase | undefined = undefined;
	input: T_Input;
	output: T_Output | undefined = undefined;
	/** The JSON-RPC message associated with this action */
	message: T_Message;
	response_message: T_Response_Message | undefined = undefined;

	#cbs: Array<After_Client_Action_Callback> = [];

	constructor(app: T_App, method: Action_Method, input: T_Input, message: T_Message) {
		this.app = app;
		this.method = method;
		this.input = input;
		this.message = message;
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

	/** Process an event in the context of the app. */
	handle(
		method: keyof Actions_Api,
		phase: Action_Phase,
		response_message?: T_Response_Message,
		log?: Logger,
	): unknown {
		if (this.phase === phase) {
			throw new Error('Client_Action_Event has already been handled for this phase');
		}
		console.log('[actions_api] handle_message', method, phase);
		console.log(`[actions_api] event`, this);

		const handlers_by_phase = this.app.action_handlers[method];
		if (!handlers_by_phase) {
			log?.error(`missing handlers for action ${method}`);
			return;
		}

		this.phase = phase;
		this.response_message = response_message;

		const handler = (handlers_by_phase as any)[phase]; // TODO @api type

		if (!handler) {
			log?.error(`missing handler for action ${method}.${phase}`);
			return;
		}

		this.output = handler(this);

		void this.#flush_after_client_action(); // not awaited because these are side effects, also supports sync functions

		return this.output;
	}
}
