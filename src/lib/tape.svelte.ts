import type {Model} from '$lib/model.svelte.js';
import {Uuid} from '$lib/uuid.js';
import type {Chat_Message} from '$lib/chat.svelte.js';
import type {Zzz} from '$lib/zzz.svelte.js';

export class Tape {
	readonly id: Uuid;
	readonly model: Model;
	messages: Array<Chat_Message> = $state([]);

	readonly zzz: Zzz;

	constructor(model: Model, id: Uuid = Uuid.parse(undefined)) {
		this.id = id;
		this.model = model;
		this.zzz = model.zzz;
	}

	add_message(message: Chat_Message): void {
		this.messages.push(message);
	}
}
