import type {Client_Message, Server_Message} from '$lib/zzz_message.js';

export interface Zzz_Client_Options {
	send: (message: Client_Message) => void;
	receive: (message: Server_Message) => void;
}

// TODO rename?

// TODO reactive?
export class Zzz_Client {
	#send: (message: Client_Message) => void;
	#receive: (message: Server_Message) => void;

	constructor(options: Zzz_Client_Options) {
		console.log('[zzz_client] creating');
		this.#send = options.send;
		this.#receive = options.receive;
	}

	send(message: Client_Message): void {
		console.log(`[zzz_client.send] message`, message.id, message.type);
		this.#send(message);
	}

	receive(message: Server_Message): void {
		console.log(`[zzz_client.receive] message`, message.id, message.type);
		this.#receive(message);
	}
}
