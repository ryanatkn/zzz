import {create_client_id_creator} from '@ryanatkn/belt/id.js';

import type {Model} from '$lib/model.svelte.js';
import {
	to_completion_response_text,
	type Completion_Request,
	type Completion_Response,
} from '$lib/completion.js';
import {random_id, type Id} from '$lib/id.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import type {Async_Status} from '@ryanatkn/belt/async.js';

const new_chat_name_id = create_client_id_creator('new chat ', 1, '');
const create_new_chat_name = (): string => new_chat_name_id();

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
	name: string = $state(create_new_chat_name());
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
		if (!message_updated) return;
		message_updated.response = response.completion_response;

		// Infer a name for the chat now that we have a response.
		// Don't await because callers don't care about the result.
		void this.init_name(message_updated);
	}

	init_name_status: Async_Status = $state('initial');

	/**
	 * Uses an LLM to name the chat based on the current messages.
	 */
	async init_name(chat_message: Chat_Message): Promise<void> {
		if (this.init_name_status !== 'initial') return; // TODO BLOCK what if this returned a deferred, so callers can correctly await it?

		this.init_name_status = 'pending';

		let p = `Output a short name for this chat with no additional commentary.
			This is a short and descriptive phrase that's used by humans to refer to this chat in the future,
			and it should be related to the content.
			Prefer lowercase unless it's a proper noun or acronym.`;

		// TODO hacky, needs better conventions
		p += `\n<User_Message>${chat_message.text}</User_Message>`;
		if (chat_message.response) {
			p += `\n<Assistant_Message> ${to_completion_response_text(chat_message.response)}</Assistant_Message>`;
		}

		try {
			// TODO BLOCK configure this utility LLM (roles?), and set the output token count from config as well
			const name_response = await this.zzz.send_prompt(p, 'ollama', 'llama3.2:3b');
			const response_text = to_completion_response_text(name_response.completion_response);
			console.log(`response_text`, response_text);
			if (!response_text) {
				console.error('unknown inference failure', name_response);
				this.init_name_status = 'initial'; // ignore failures, will retry
				return;
			}
			this.init_name_status = 'success';
			this.name = response_text; // TODO handle duplicates
		} catch (err) {
			this.init_name_status = 'initial'; // ignore failures, will retry
			console.error('failed to infer a name for a chat', err);
		}
	}
}
