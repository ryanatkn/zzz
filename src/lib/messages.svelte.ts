import {
	create_message_with_metadata,
	type Client_Message,
	type Server_Message,
	type Message_Direction,
} from '$lib/api.js';
import {Message} from '$lib/message.svelte.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {Uuid} from '$lib/uuid.js';

export class Messages {
	readonly zzz: Zzz;

	items: Array<Message> = $state([]);

	#send_handler: (message: Client_Message) => void;
	#receive_handler: (message: Server_Message) => void;

	constructor(zzz: Zzz) {
		this.zzz = zzz;

		// Default no-op handlers that log errors with instructions
		this.#send_handler = (message) => {
			console.error(
				'[messages.send] No send handler registered. Set handlers with zzz.messages.set_handlers().',
				message,
			);
		};

		this.#receive_handler = (message) => {
			console.error(
				'[messages.receive] No receive handler registered. Set handlers with zzz.messages.set_handlers().',
				message,
			);
		};
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
		this.#send_handler(message);
		this.add_message(message, 'client');
	}

	receive(message: Server_Message): void {
		console.log(`[messages.receive] message`, message.id, message.type);
		this.#receive_handler(message);
		this.add_message(message, 'server');
	}

	add_message(data: unknown, direction: Message_Direction): void {
		const base_message = data as {id: Uuid; type: string};
		const message_json = create_message_with_metadata(base_message as any, direction);
		const message = new Message({zzz: this.zzz, json: message_json});
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
