import {z} from 'zod';
import type {Async_Status} from '@ryanatkn/belt/async.js';

import type {Model} from '$lib/model.svelte.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import {Completion_Request} from '$lib/message_types.js';
import {Uuid, Datetime_Now} from '$lib/zod_helpers.js';
import {get_unique_name} from '$lib/helpers.js';
import {Tape} from '$lib/tape.svelte.js';
import {Tape_Json} from '$lib/tape_types.js';
import type {Prompt} from '$lib/prompt.svelte.js';
import {reorder_list} from '$lib/list_helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {type Chat_Message, create_chat_message} from '$lib/chat_message.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';

const NEW_CHAT_PREFIX = 'new chat';

const chat_names: Array<string> = [];

export const Chat_Json = Cell_Json.extend({
	id: Uuid,
	name: z.string().default(() => {
		// TODO BLOCK how to do this correctly? can you make it stateful and still have a static module-scoped schema? I dont see a context object arg or anything
		const name = get_unique_name('chat', chat_names);
		chat_names.push(name);
		return name;
	}),
	created: Datetime_Now,
	tapes: z.array(Tape_Json).default(() => []),
	selected_prompt_ids: z.array(Uuid).default(() => []), // TODO consider making these refs, automatic classes (maybe as separate properties by convention, so the original is still the plain ids)
});

export type Chat_Json = z.infer<typeof Chat_Json>;

export interface Chat_Options extends Cell_Options<typeof Chat_Json> {}

export class Chat extends Cell<typeof Chat_Json> {
	name: string = $state()!;
	tapes: Array<Tape> = $state([]);
	selected_prompts: Array<Prompt> = $state([]);

	init_name_status: Async_Status = $state('initial');

	constructor(options: Chat_Options) {
		super(Chat_Json, options);

		// Initialize parsers with type-specific handlers
		this.parsers = {
			name: (value) => {
				// If name is undefined, generate a unique name
				if (value === undefined) {
					return get_unique_name(
						NEW_CHAT_PREFIX,
						this.zzz.chats.items.map((c) => c.name),
					);
				}
				return undefined; // Let the schema handle it
			},
			selected_prompt_ids: (value) => {
				if (Array.isArray(value)) {
					return value
						.map((id) => this.zzz.prompts.items.find((p) => p.id === id)?.id)
						.filter((p) => p !== undefined);
				}
				return undefined;
			},
		};

		// Initialize the instance
		this.init();
	}

	add_tape(model: Model): void {
		this.tapes.push(
			new Tape({
				zzz: this.zzz,
				json: {model_name: model.name},
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

		// Create a properly typed completion request
		const completion_request = Completion_Request.parse({
			created: Datetime_Now.parse(undefined),
			request_id: message_id,
			provider_name: tape.model.provider_name,
			model: tape.model.name,
			prompt: content,
		});

		// Create user message using the helper function
		const message = create_chat_message(content, 'user', {
			id: message_id, // Override the auto-generated ID
			request: completion_request,
		});

		tape.add_chat_message(message);

		// TODO this seems messy, probably refactor
		// Build message history for the AI - ensure all content is a string
		const tape_history = tape.chat_messages
			.filter((m) => m.id !== message_id) // Exclude the current message
			.map((m) => ({
				role: m.role,
				content:
					m.role === 'assistant' && m.response
						? to_completion_response_text(m.response) || '' // Ensure content is not null/undefined
						: m.content,
			}));

		// Send the prompt with tape history
		const response = await this.zzz.send_prompt(
			content,
			tape.model.provider_name,
			tape.model.name,
			tape_history,
		);

		// Find the message we just added
		const message_updated = tape.chat_messages_by_id.get(message_id);
		if (!message_updated) return;

		// Get the response text
		const response_text = to_completion_response_text(response.completion_response) || '';

		// Add the assistant's response as a separate message
		const assistant_message = create_chat_message(response_text, 'assistant', {
			tape_id: message_updated.tape_id,
		});

		tape.add_chat_message(assistant_message);

		// Infer a name for the chat now that we have a response.
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
			const responseText = to_completion_response_text(chat_message.response) || '';
			p += `\n<Assistant_Message>${responseText}</Assistant_Message>`;
		}

		try {
			// TODO BLOCK configure this utility LLM (roles?), and set the output token count from config as well
			const name_response = await this.zzz.send_prompt(p, 'ollama', 'llama3.2:3b');
			const completion_response = name_response.completion_response;
			// Add null check here
			// TODO BLOCK maybe make nullable? would silence this linting issue:
			if (!completion_response) {
				console.error('No completion response received');
				this.init_name_status = 'initial';
				return;
			}
			const response_text = to_completion_response_text(completion_response) || '';
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

	/**
	 * Reorder tapes by moving from one index to another
	 */
	reorder_tapes(from_index: number, to_index: number): void {
		if (from_index === to_index) return;
		if (from_index < 0 || from_index >= this.tapes.length) return;
		if (to_index < 0 || to_index >= this.tapes.length) return;

		reorder_list(this.tapes, from_index, to_index);
	}
}
