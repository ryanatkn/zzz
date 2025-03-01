import type {
	Client_Message,
	Server_Message,
	Message_Json,
	Message_Direction,
} from '$lib/message.svelte.js';
import {Message} from '$lib/message.svelte.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {Uuid} from '$lib/uuid.js';

export interface Messages_Options {
	zzz: Zzz;
	send: (message: Client_Message) => void;
	receive: (message: Server_Message) => void;
}

export class Messages {
	readonly zzz: Zzz;

	items: Array<Message> = $state([]);

	#send_handler: ((message: Client_Message) => void) | undefined;
	#receive_handler: ((message: Server_Message) => void) | undefined;

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	set_handlers(
		send_handler: (message: Client_Message) => void,
		receive_handler: (message: Server_Message) => void,
	): void {
		this.#send_handler = send_handler;
		this.#receive_handler = receive_handler;
	}

	send(message: Client_Message): void {
		console.log(`[messages.send] message`, message.id, message.type);
		if (this.#send_handler) {
			this.#send_handler(message);
		} else {
			console.error('[messages.send] No send handler registered');
		}
		this.add_message(message, 'client');
	}

	receive(message: Server_Message): void {
		console.log(`[messages.receive] message`, message.id, message.type);
		if (this.#receive_handler) {
			this.#receive_handler(message);
		} else {
			console.error('[messages.receive] No receive handler registered');
		}
		this.add_message(message, 'server');
	}

	add_message(data: unknown, direction: Message_Direction): void {
		const base_message = data as {id: Uuid; type: string};
		const json: Message_Json = {
			id: base_message.id,
			type: base_message.type as any, // Type coercion needed here
			direction,
			data,
			created_at: new Date().toISOString(),
		};
		const message = new Message({zzz: this.zzz, json});
		this.items.unshift(message); // Add at the beginning for newest first

		// Limit message history to prevent performance issues
		if (this.items.length > 100) {
			this.items = this.items.slice(0, 100);
		}
	}

	find_by_id(id: Uuid): Message | undefined {
		return this.items.find((m) => m.id === id);
	}

	filter_by_type(type: string): Array<Message> {
		return this.items.filter((m) => m.type === type);
	}

	clear(): void {
		this.items.length = 0;
	}
}
