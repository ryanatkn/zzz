import type {Omit_Strict} from '@ryanatkn/belt/types.js';
import type {Client_Message, Server_Message} from './zzz_message.js';
import {random_id} from './id.js';

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
		const m = {id: undefined as any, ...message} as Client_Message;
		m.id = random_id(); // this pattern puts id first, and ensures `message` cannot override it
		this.#send(m);
	}

	receive(message: Server_Message): void {
		console.log(`[zzz_client.receive] message`, message);
		this.#receive(message);
	}
}
