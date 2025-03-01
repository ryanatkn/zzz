import type {Model} from '$lib/model.svelte.js';
import {Uuid} from '$lib/uuid.js';
import type {Chat_Message} from '$lib/chat.svelte.js';

export class Tape {
	readonly id: Uuid;
	readonly model: Model;
	messages: Array<Chat_Message> = $state([]);

	constructor(model: Model, id: Uuid = Uuid.parse(null)) {
		this.id = id;
		this.model = model;
	}

	add_message(message: Chat_Message): void {
		this.messages.push(message);
	}
}
