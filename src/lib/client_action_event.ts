import type {Logger} from '@ryanatkn/belt/log.js';

import type {Action_Method, Actions_Api} from '$lib/action_metatypes.js';
import type {Zzz_App} from '$lib/zzz_app.svelte.js';
import type {Action_Input, Action_Output, Action_Phase} from '$lib/action_types.js';
import type {
	Jsonrpc_Notification,
	Jsonrpc_Response_Or_Error,
	Jsonrpc_Singular_Message,
} from '$lib/jsonrpc.js';
import {
	is_jsonrpc_notification,
	is_jsonrpc_request,
	is_jsonrpc_response,
} from '$lib/jsonrpc_helpers.js';

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
	T_Request_Message extends Jsonrpc_Singular_Message | undefined =
		| Jsonrpc_Singular_Message
		| undefined,
	T_Response_Message extends Jsonrpc_Response_Or_Error | undefined =
		| Jsonrpc_Response_Or_Error
		| undefined,
	T_Notification_Message extends Jsonrpc_Notification | undefined =
		| Jsonrpc_Notification
		| undefined,
> {
	app: T_App;
	/** JSON-RPC method for the action. */
	method: Action_Method;
	/** The phase of the action handling event/context. */
	phase: Action_Phase | undefined = undefined;
	input: T_Input;
	output!: T_Output; // TODO @api @many error-prone bc `undefined` must be passed explicitly without any typechecker helper, a type union would be better

	/** The JSON-RPC request message associated with this action, if any. */
	request_message!: T_Request_Message; // TODO @api @many error-prone bc `undefined` must be passed explicitly without any typechecker helper, a type union would be better
	/** The JSON-RPC response message associated with this action, if any. */
	response_message!: T_Response_Message; // TODO @api @many error-prone bc `undefined` must be passed explicitly without any typechecker helper, a type union would be better
	/** The JSON-RPC notification message associated with this action, if any. */
	notification_message!: T_Notification_Message; // TODO @api @many error-prone bc `undefined` must be passed explicitly without any typechecker helper, a type union would be better

	#after_cbs: Array<After_Client_Action_Callback> = [];

	constructor(
		app: T_App,
		method: Action_Method,
		input: T_Input,
		message: T_Request_Message | T_Notification_Message | null,
	) {
		this.app = app;
		this.method = method;
		this.input = input;
		if (message) {
			if (is_jsonrpc_request(message)) {
				this.request_message = message as T_Request_Message;
			} else if (is_jsonrpc_notification(message)) {
				this.notification_message = message as T_Notification_Message;
			} else {
				throw new Error(`Invalid message type for Client_Action_Event`);
			}
		}
	}

	async #flush_after_client_action(): Promise<void> {
		for (const cb of this.#after_cbs) {
			await cb(); // eslint-disable-line no-await-in-loop
		}
	}

	/** Adds a callback hook that runs after the event is handled. */
	after(after_cb: After_Client_Action_Callback): void {
		this.#after_cbs.push(after_cb);
	}

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

		if (response_message) {
			this.response_message = response_message;
		}

		const handler = handlers_by_phase[phase]; // TODO BLOCK @many @api type

		if (!handler) {
			log?.error(`missing handler for action ${method}.${phase}`);
			return;
		}

		if (is_jsonrpc_response(response_message)) {
			this.output = response_message.result; // TODO BLOCK @many @api type need to extract _meta here
		}
		// TODO handle error case? can read the `response_message` but maybe we want a more explicit API

		// TODO BLOCK @api not sure about this
		const returned = handler(this);
		if (returned !== undefined) {
			this.output = returned;
		}

		void this.#flush_after_client_action(); // not awaited because these are side effects, also supports sync functions

		return this.output;
	}
}
