import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Server_Action_Handler} from '$lib/server/server_action_handler.js';
import type {Action_Input, Action_Output, Action_Phase} from '$lib/action_types.js';
import type {
	Jsonrpc_Message_From_Client_To_Server,
	Jsonrpc_Message_From_Server_To_Client,
} from '$lib/jsonrpc.js';

// TODO @api improve types

export class Server_Action_Event<
	// TODO @api should these be named params/output at this boundary?
	T_Input extends Action_Input = any, // TODO @api type
	T_Output extends Action_Output = any, // TODO @api type
	T_Message extends Jsonrpc_Message_From_Client_To_Server = Jsonrpc_Message_From_Client_To_Server,
	T_Response extends Jsonrpc_Message_From_Server_To_Client = Jsonrpc_Message_From_Server_To_Client,
> {
	server: Zzz_Server;
	phase: Action_Phase;
	input: T_Input;
	/**
	 * The incoming JSON-RPC message from the client, like a request or notification.
	 */
	message: T_Message;

	/**
	 * The result of the action, which is set after the handler is executed.
	 */
	output: T_Output | undefined = undefined;

	/**
	 * The outgoing JSON-RPC message, if any. Set after the handler is executed.
	 */
	response: T_Response | undefined = undefined;

	handled: boolean = false;

	constructor(server: Zzz_Server, phase: Action_Phase, input: T_Input, message: T_Message) {
		this.server = server;
		this.phase = phase;
		this.input = input;
		this.message = message;
	}

	async handle(handler: Server_Action_Handler): Promise<void> {
		if (this.handled) {
			throw new Error('Server_Action_Event has already been handled');
		}
		this.handled = true;

		this.output = await handler(this);
	}
}
