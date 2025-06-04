import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Server_Action_Handler} from '$lib/server/server_action_handler.js';
import type {Action_Phase} from '$lib/action_types.js';
import type {Jsonrpc_Message_From_Client_To_Server} from '$lib/jsonrpc.js';

export class Server_Action_Event<
	T_Params = any,
	T_Result = any,
	T_Message extends Jsonrpc_Message_From_Client_To_Server = Jsonrpc_Message_From_Client_To_Server,
> {
	server: Zzz_Server;
	phase: Action_Phase;
	params: T_Params;
	message: T_Message;

	handled: boolean = false;

	/**
	 * The result of the action, which is set after the handler is executed.
	 */
	result: T_Result | undefined;

	constructor(server: Zzz_Server, phase: Action_Phase, params: T_Params, message: T_Message) {
		this.server = server;
		this.phase = phase;
		this.params = params;
		this.message = message;
	}

	async handle(handler: Server_Action_Handler): Promise<void> {
		if (this.handled) {
			throw new Error('Server_Action_Event has already been handled');
		}
		this.handled = true;
		this.result = await handler(this);
	}
}
