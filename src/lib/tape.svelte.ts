import type {Model} from '$lib/model.svelte.js';
import {random_id, type Id} from '$lib/id.js';
import type {Chat_Message} from '$lib/chat.svelte.js';

export class Tape {
	readonly id: Id;
	readonly model: Model;
	messages: Array<Chat_Message> = $state([]);

	constructor(model: Model, id: Id = random_id()) {
		this.id = id;
		this.model = model;
	}

	add_message(message: Chat_Message): void {
		this.messages.push(message);
	}
}
