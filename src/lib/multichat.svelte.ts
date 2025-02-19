import type {Model} from '$lib/model.svelte.js';
import type {Completion_Request, Completion_Response} from '$lib/completion.js';
import {random_id, type Id} from '$lib/id.js';
import type {Zzz} from '$lib/zzz.svelte.js';

export interface Chat_Message {
	id: Id;
	timestamp: string;
	text: string;
	request?: Completion_Request;
	response?: Completion_Response;
}

export interface Tape {
	id: Id;
	model: Model;
	messages: Array<Chat_Message>;
}

export class Multichat {
	tapes: Array<Tape> = $state([]);
	zzz: Zzz;

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	add_tape(model: Model): void {
		this.tapes.push({
			id: random_id(),
			model,
			messages: [],
		});
	}

	remove_tape(id: Id): void {
		const index = this.tapes.findIndex((s) => s.id === id);
		if (index !== -1) this.tapes.splice(index, 1);
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

		const msg_id = random_id();
		const message: Chat_Message = {
			id: msg_id,
			timestamp: new Date().toISOString(),
			text,
			request: {
				created: new Date().toISOString(),
				request_id: msg_id,
				provider_name: tape.model.provider_name,
				model: tape.model.name,
				prompt: text,
			},
		};

		tape.messages.push(message);

		const response = await this.zzz.send_prompt(text, tape.model.provider_name, tape.model.name);

		// TODO refactor
		const msg = tape.messages.find((m) => m.id === msg_id);
		if (msg) msg.response = response.completion_response;
	}
}
