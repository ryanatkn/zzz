import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Jsonrpc_Params} from '$lib/jsonrpc.js';
import type {Action_Message_Base} from '$lib/action_types.js';
import type {Server_Action_Handler} from './server_action_handler.js';

export class Server_Action_Event<
	T_Params extends Jsonrpc_Params = any,
	T_Result = any,
	T_Message extends Action_Message_Base = any,
> {
	server: Zzz_Server;
	params: T_Params;
	message: T_Message;

	handled: boolean = false;

	/**
	 * The result of the action, which is set after the handler is executed.
	 */
	result: T_Result | undefined;

	constructor(server: Zzz_Server, params: T_Params, message: T_Message) {
		this.server = server;
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
