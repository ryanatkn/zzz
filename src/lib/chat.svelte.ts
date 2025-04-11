import {z} from 'zod';
import type {Async_Status} from '@ryanatkn/belt/async.js';
import {encode as tokenize} from 'gpt-tokenizer';

import type {Model} from '$lib/model.svelte.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Tape} from '$lib/tape.svelte.js';
import type {Prompt} from '$lib/prompt.svelte.js';
import {reorder_list} from '$lib/list_helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import type {Bit_Type} from '$lib/bit.svelte.js';
import {get_unique_name} from '$lib/helpers.js';

const Chat_View_Mode = z.enum(['simple', 'multi']).default('simple');
export type Chat_View_Mode = z.infer<typeof Chat_View_Mode>;

export const Chat_Json = Cell_Json.extend({
	name: z.string().default(''),
	tape_ids: z.array(Uuid).default(() => []),
	selected_prompt_ids: z.array(Uuid).default(() => []), // TODO consider making these refs, automatic classes (maybe as separate properties by convention, so the original is still the plain ids)
	main_input: z.string().default(''),
	view_mode: Chat_View_Mode,
});
export type Chat_Json = z.infer<typeof Chat_Json>;
export type Chat_Json_Input = z.input<typeof Chat_Json>;

export interface Chat_Options extends Cell_Options<typeof Chat_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Chat extends Cell<typeof Chat_Json> {
	name: string = $state()!;
	tape_ids: Array<Uuid> = $state()!;
	selected_prompt_ids: Array<Uuid> = $state()!;
	main_input: string = $state()!;
	view_mode: Chat_View_Mode = $state()!;

	readonly main_input_length: number = $derived(this.main_input.length);
	readonly main_input_tokens: Array<number> = $derived(tokenize(this.main_input));
	readonly main_input_token_count: number = $derived(this.main_input_tokens.length);

	// TODO look into using an index for this, incremental from `this.tape_ids`
	readonly tapes: Array<Tape> = $derived.by(() => {
		const result: Array<Tape> = [];
		const {by_id} = this.zzz.tapes.items;

		for (const id of this.tape_ids) {
			const tape = by_id.get(id);
			if (tape) {
				result.push(tape);
			}
		}

		return result;
	});

	readonly enabled_tapes = $derived(this.tapes.filter((t) => t.enabled)); // TODO indexed collection, also disabled variant?

	// TODO maybe add a derived property for the ids that are selected but missing?
	readonly selected_prompts: Array<Prompt> = $derived.by(() => {
		const result: Array<Prompt> = [];
		const {by_id} = this.zzz.prompts.items;

		for (const id of this.selected_prompt_ids) {
			const prompt = by_id.get(id);
			if (prompt) {
				result.push(prompt);
			}
		}

		return result;
	});

	// TODO `Bits` class instead? same as on zzz?
	readonly bits: Set<Bit_Type> = $derived.by(() => {
		const b: Set<Bit_Type> = new Set();
		for (const prompt of this.selected_prompts) {
			for (const bit of prompt.bits) {
				b.add(bit);
			}
		}
		return b;
	});
	readonly bits_array: Array<Bit_Type> = $derived(Array.from(this.bits));

	init_name_status: Async_Status = $state('initial');

	constructor(options: Chat_Options) {
		super(Chat_Json, options);
		this.init();
	}

	add_tape(model: Model): void {
		const tape = new Tape({zzz: this.zzz, json: {model_name: model.name}});
		this.zzz.tapes.add_tape(tape);
		this.tape_ids.push(tape.id);
	}

	add_tapes_by_model_tag(tag: string): void {
		for (const model of this.zzz.models.filter_by_tag(tag)) {
			this.add_tape(model);
		}
	}

	remove_tape(id: Uuid): void {
		const index = this.tape_ids.findIndex((tape_id) => tape_id === id);
		if (index !== -1) {
			this.tape_ids.splice(index, 1);
		}
	}

	remove_tapes(ids: Array<Uuid>): void {
		this.tape_ids = this.tape_ids.filter((t) => !ids.includes(t));
	}

	remove_tapes_by_model_tag(tag: string): void {
		for (const tape of this.tapes.filter((t) => t.model.tags.includes(tag))) {
			this.remove_tape(tape.id);
		}
	}

	remove_all_tapes(): void {
		this.tape_ids.length = 0;
	}

	add_selected_prompt(prompt_id: Uuid): void {
		if (!this.selected_prompt_ids.some((id) => id === prompt_id)) {
			this.selected_prompt_ids.push(prompt_id);
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
		await Promise.all(
			// TODO batch endpoint
			this.enabled_tapes.map((tape) => this.send_to_tape(tape.id, content)),
		);
	}

	async send_to_tape(tape_id: Uuid, content: string): Promise<void> {
		const tape = this.tapes.find((s) => s.id === tape_id);
		if (!tape) return;

		const assistant_strip = await tape.send_message(content);

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
			// TODO configure this utility LLM (roles?), and set the output token count from config as well
			const name_response = await this.zzz.send_prompt(
				p,
				// TODO @many hacky, rework the bots interface (currently just copies over the config) - the provider should be on the model object, but should models be able to have multiple providers, or do they need unique names? and another field for canonical model name?
				this.zzz.models.find_by_name(this.zzz.bots.namerbot)!.provider_name,
				this.zzz.bots.namerbot,
			);
			const {completion_response} = name_response;

			const response_text = to_completion_response_text(completion_response) || '';

			if (!response_text) {
				console.error('unknown inference failure', name_response);
				this.init_name_status = 'initial'; // ignore failures, will retry
				return;
			}

			this.init_name_status = 'success';
			if (response_text !== this.name) {
				this.name = get_unique_name(response_text, this.zzz.chats.items_by_name);
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
		reorder_list(this.tape_ids, from_index, to_index);
	}
}

export const Chat_Schema = z.instanceof(Chat);
