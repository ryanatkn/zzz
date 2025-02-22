import type {Model} from '$lib/model.svelte.js';
import type {Completion_Request, Completion_Response} from '$lib/completion.js';
import {random_id, type Id} from '$lib/id.js';
import type {Zzz} from '$lib/zzz.svelte.js';

export interface Chat_Message {
	id: Id;
	created: string;
	text: string;
	request?: Completion_Request;
	response?: Completion_Response;
}

export interface Tape {
	id: Id;
	model: Model;
	messages: Array<Chat_Message>;
}

export class Chat {
	// TODO json pattern
	id: Id = random_id();
	name: string = $state('');
	created: string = new Date().toISOString();
	tapes: Array<Tape> = $state([]);
	zzz: Zzz;

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	add_tape(model: Model): void {
		console.log(`add_tape model`, model);
		this.tapes.push({
			id: random_id(),
			model,
			messages: [],
		});
	}

	add_tapes_by_model_tag(tag: string): void {
		for (const model of this.zzz.models.items.filter((m) => m.tags.includes(tag))) {
			this.add_tape(model);
		}
	}

	remove_tape(id: Id): void {
		const index = this.tapes.findIndex((s) => s.id === id);
		if (index !== -1) this.tapes.splice(index, 1);
	}

	remove_tapes_by_model_tag(tag: string): void {
		for (const tape of this.tapes.filter((t) => t.model.tags.includes(tag))) {
			this.remove_tape(tape.id);
		}
	}

	remove_all_tapes(): void {
		this.tapes.length = 0;
	}

	async send_to_all(text: string): Promise<void> {
		await Promise.all(this.tapes.map((tape) => this.send_to_tape(tape.id, text)));
	}

	async send_to_tape(tape_id: Id, text: string): Promise<void> {
		const tape = this.tapes.find((s) => s.id === tape_id);
		if (!tape) return;

		const message_id = random_id();
		const message: Chat_Message = {
			id: message_id,
			// TODO add `chat_id`?
			created: new Date().toISOString(),
			text,
			request: {
				created: new Date().toISOString(),
				request_id: message_id,
				provider_name: tape.model.provider_name,
				model: tape.model.name,
				prompt: text,
			},
		};

		tape.messages.push(message);

		const response = await this.zzz.send_prompt(text, tape.model.provider_name, tape.model.name);

		// TODO refactor
		const message_updated = tape.messages.find((m) => m.id === message_id);
		if (message_updated) message_updated.response = response.completion_response;
	}
}
