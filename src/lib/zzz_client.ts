import type {Client_Message, Server_Message} from './zzz_message.js';

export interface Options {
	send: (message: Client_Message) => void;
	receive: (message: Server_Message) => void;
}

// TODO reactive?
export class Zzz_Client {
	#send: (message: Client_Message) => void;
	#receive: (message: Server_Message) => void;

	constructor(options: Options) {
		console.log('[zzz_client] creating');
		this.#send = options.send;
		this.#receive = options.receive;
	}

	send(message: Client_Message): void {
		console.log(`[zzz_client.send] message`, message);
		this.#send(message);
	}

	receive(message: Server_Message): void {
		console.log(`[zzz_client.receive] message`, message);
		this.#receive(message);
	}
}
