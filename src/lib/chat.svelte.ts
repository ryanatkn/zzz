import {z} from 'zod';
import type {Async_Status} from '@ryanatkn/belt/async.js';
import {encode as tokenize} from 'gpt-tokenizer';

import type {Model} from '$lib/model.svelte.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';
import {get_unique_name} from '$lib/helpers.js';
import {Tape} from '$lib/tape.svelte.js';
import {Tape_Json} from '$lib/tape_types.js';
import type {Prompt} from '$lib/prompt.svelte.js';
import {reorder_list} from '$lib/list_helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {USE_DEFAULT} from '$lib/cell_helpers.js';
import type {Bit_Type} from '$lib/bit.svelte.js';

const NEW_CHAT_PREFIX = 'chat';

const chat_names: Array<string> = [];

export const Chat_Json = Cell_Json.extend({
	name: z.string().default(() => {
		// TODO BLOCK how to do this correctly? can you make it stateful and still have a static module-scoped schema? I dont see a context object arg or anything
		const name = get_unique_name('chat', chat_names);
		chat_names.push(name);
		return name;
	}),
	tapes: z.array(Tape_Json).default(() => []),
	selected_prompt_ids: z.array(Uuid).default(() => []), // TODO consider making these refs, automatic classes (maybe as separate properties by convention, so the original is still the plain ids)
	main_input: z.string().default(''),
});

export type Chat_Json = z.infer<typeof Chat_Json>;

export interface Chat_Options extends Cell_Options<typeof Chat_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type
export class Chat extends Cell<typeof Chat_Json> {
	name: string = $state()!;
	tapes: Array<Tape> = $state([]);
	selected_prompt_ids: Array<Uuid> = $state()!;

	main_input: string = $state('');
	main_input_length: number = $derived(this.main_input.length);
	main_input_tokens: Array<number> = $derived(tokenize(this.main_input));
	main_input_token_count: number = $derived(this.main_input_tokens.length);

	// TODO maybe add a derived property for the ids that are selected but missing?
	selected_prompts: Array<Prompt> = $derived(
		this.selected_prompt_ids.map((id) => this.zzz.prompts.items.by_id.get(id)).filter((p) => !!p), // TODO BLOCK optimize to avoid the filter
	);

	// TODO `Bits` class instead? same as on zzz?
	bits: Set<Bit_Type> = $derived.by(() => {
		const b: Set<Bit_Type> = new Set();
		for (const prompt of this.selected_prompts) {
			for (const bit of prompt.bits) {
				b.add(bit);
			}
		}
		return b;
	});
	bits_array: Array<Bit_Type> = $derived(Array.from(this.bits));

	init_name_status: Async_Status = $state('initial');

	constructor(options: Chat_Options) {
		super(Chat_Json, options);

		// Initialize decoders with type-specific handlers
		this.decoders = {
			name: (value) => {
				// If name is undefined, generate a unique name
				if (value === undefined) {
					return get_unique_name(
						NEW_CHAT_PREFIX,
						this.zzz.chats.items.all.map((c) => c.name),
					);
				}
				return USE_DEFAULT; // Explicitly use the default decoding
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
		for (const model of this.zzz.models.items.all.filter((m) => m.tags.includes(tag))) {
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
		if (!this.selected_prompt_ids.some((id) => id === prompt.id)) {
			this.selected_prompt_ids.push(prompt.id);
		}
	}

	remove_selected_prompt(prompt_id: Uuid): void {
		const index = this.selected_prompt_ids.findIndex((id) => id === prompt_id);
		if (index !== -1) {
			this.selected_prompt_ids.splice(index, 1);
		}
	}

	reorder_selected_prompts(from_index: number, to_index: number): void {
		reorder_list(this.selected_prompt_ids, from_index, to_index);
	}

	async send_to_all(content: string): Promise<void> {
		await Promise.all(this.tapes.map((tape) => this.send_to_tape(tape.id, content)));
	}

	async send_to_tape(tape_id: Uuid, content: string): Promise<void> {
		const tape = this.tapes.find((s) => s.id === tape_id);
		if (!tape) return;

		const assistant_strip = await tape.send_message(content);

		// Infer a name for the chat now that we have a response
		// No more type error as strip.content now always returns a string
		void this.init_name_from_strips(content, assistant_strip.content);
	}

	/**
	 * Uses an LLM to name the chat based on the user input and AI response.
	 */
	async init_name_from_strips(user_content: string, assistant_content: string): Promise<void> {
		if (this.init_name_status !== 'initial') return;

		this.init_name_status = 'pending';

		let p = `Output a short name for this chat with no additional commentary.
			This is a short and descriptive phrase that's used by humans to refer to this chat in the future,
			and it should be related to the content.
			Prefer lowercase unless it's a proper noun or acronym.`;

		p += `<User_Message>${user_content}</User_Message>`;
		p += `\n<Assistant_Message>${assistant_content}</Assistant_Message>`;

		try {
			// TODO BLOCK configure this utility LLM (roles?), and set the output token count from config as well
			const name_response = await this.zzz.send_prompt(p, 'ollama', 'llama3.2:3b');
			const completion_response = name_response.completion_response;

			if (!completion_response) {
				console.error('No completion response received');
				this.init_name_status = 'initial';
				return;
			}

			const response_text = to_completion_response_text(completion_response) || '';

			if (!response_text) {
				console.error('unknown inference failure', name_response);
				this.init_name_status = 'initial'; // ignore failures, will retry
				return;
			}

			this.init_name_status = 'success';
			if (response_text !== this.name) {
				this.name = get_unique_name(
					response_text,
					this.zzz.chats.items.all.map((c) => c.name),
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

export const Chat_Schema = z.instanceof(Chat);
