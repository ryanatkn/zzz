import {z} from 'zod';
import type {Async_Status} from '@ryanatkn/belt/async.js';

import type {Model} from '$lib/model.svelte.js';
import {
	to_completion_response_text,
	type Completion_Request,
	type Completion_Response,
} from '$lib/completion.js';
import {Uuid} from '$lib/uuid.js';
import {get_unique_name} from '$lib/helpers.js';
import {Tape, Tape_Json} from '$lib/tape.svelte.js';
import type {Prompt} from '$lib/prompt.svelte.js';
import {reorder_list} from '$lib/list_helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Datetime_Now} from '$lib/zod_helpers.js';

const NEW_CHAT_PREFIX = 'new chat';

export interface Chat_Message {
	id: Uuid;
	created: Datetime_Now;
	content: string; // renamed from text
	request?: Completion_Request;
	response?: Completion_Response;
}

const chat_names: Array<string> = [];

export const Chat_Json = z
	.object({
		id: Uuid,
		name: z.string().default(() => {
			// TODO BLOCK how to do this correctly? can you make it stateful and still have a static module-scoped schema? I dont see a context object arg or anything
			const name = get_unique_name('chat', chat_names);
			chat_names.push(name);
			return name;
		}),
		created: Datetime_Now,
		tapes: z.array(Tape_Json).default(() => []),
		selected_prompt_ids: z.array(Uuid).default(() => []),
	})
	.default(() => ({}));

export type Chat_Json = z.infer<typeof Chat_Json>;

export interface Chat_Options extends Cell_Options<typeof Chat_Json> {}

export class Chat extends Cell<typeof Chat_Json> {
	id: Uuid = $state()!;
	name: string = $state()!;
	created: Datetime_Now = $state()!;
	tapes: Array<Tape> = $state([]);
	selected_prompts: Array<Prompt> = $state([]);

	init_name_status: Async_Status = $state('initial');

	constructor(options: Chat_Options) {
		super(Chat_Json, options);

		if (!options.json?.name) {
			this.name = get_unique_name(
				NEW_CHAT_PREFIX,
				this.zzz.chats.items.map((c) => c.name),
			);
		}

		if (!options.json?.created) {
			this.created = Datetime_Now.parse(undefined);
		}

		this.init();

		// Handle selected prompts separately after initialization
		if (options.json?.selected_prompt_ids) {
			this.selected_prompts = options.json.selected_prompt_ids
				.map((id) => this.zzz.prompts.items.find((p) => p.id === id))
				.filter((p): p is Prompt => p !== undefined);
		}
	}

	// TODO BLOCK @many shouldn't exist, need to somehow know to only use the id instead of `$state.snapshot(thing)`
	override to_json(): z.output<typeof Chat_Json> {
		return {
			id: this.id,
			name: this.name,
			created: this.created,
			tapes: this.tapes.map((tape) => tape.json),
			selected_prompt_ids: this.selected_prompts.map((p) => p.id),
		};
	}

	add_tape(model: Model): void {
		this.tapes.push(
			new Tape({
				zzz: this.zzz,
				model,
			}),
		);
	}

	add_tapes_by_model_tag(tag: string): void {
		for (const model of this.zzz.models.items.filter((m) => m.tags.includes(tag))) {
			this.add_tape(model);
		}
	}

	remove_tape(id: Uuid): void {
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

	add_selected_prompt(prompt: Prompt): void {
		if (!this.selected_prompts.some((p) => p.id === prompt.id)) {
			this.selected_prompts.push(prompt);
		}
	}

	remove_selected_prompt(prompt_id: Uuid): void {
		const index = this.selected_prompts.findIndex((p) => p.id === prompt_id);
		if (index !== -1) {
			this.selected_prompts.splice(index, 1);
		}
	}

	reorder_selected_prompts(from_index: number, to_index: number): void {
		reorder_list(this.selected_prompts, from_index, to_index);
	}

	async send_to_all(content: string): Promise<void> {
		await Promise.all(this.tapes.map((tape) => this.send_to_tape(tape.id, content)));
	}

	async send_to_tape(tape_id: Uuid, content: string): Promise<void> {
		const tape = this.tapes.find((s) => s.id === tape_id);
		if (!tape) return;

		const message_id = Uuid.parse(undefined);
		const message: Chat_Message = {
			id: message_id,
			// TODO add `chat_id`?
			created: Datetime_Now.parse(undefined),
			content,
			request: {
				created: Datetime_Now.parse(undefined),
				request_id: message_id,
				provider_name: tape.model.provider_name,
				model: tape.model.name,
				prompt: content,
			},
		};

		tape.messages.push(message);

		const response = await this.zzz.send_prompt(content, tape.model.provider_name, tape.model.name);

		// TODO refactor
		const message_updated = tape.messages.find((m) => m.id === message_id);
		if (!message_updated) return;

		// Direct assignment instead of using helper
		message_updated.response = response.completion_response;

		// Infer a name for the chat now that we have a response.
		// Don't await because callers don't care about the result.
		void this.init_name(message_updated);
	}

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
		p += `<User_Message>${chat_message.content}</User_Message>`;
		if (chat_message.response) {
			p += `\n<Assistant_Message> ${to_completion_response_text(chat_message.response)}</Assistant_Message>`;
		}

		try {
			// TODO BLOCK configure this utility LLM (roles?), and set the output token count from config as well
			const name_response = await this.zzz.send_prompt(p, 'ollama', 'llama3.2:3b');
			// Direct assignment instead of using helper
			const completion_response = name_response.completion_response;
			const response_text = to_completion_response_text(completion_response);
			console.log(`response_text`, response_text);
			if (!response_text) {
				console.error('unknown inference failure', name_response);
				this.init_name_status = 'initial'; // ignore failures, will retry
				return;
			}
			this.init_name_status = 'success';
			if (response_text !== this.name) {
				this.name = get_unique_name(
					response_text,
					this.zzz.chats.items.map((c) => c.name),
				);
			}
		} catch (err) {
			this.init_name_status = 'initial'; // ignore failures, will retry
			console.error('failed to infer a name for a chat', err);
		}
	}
}
