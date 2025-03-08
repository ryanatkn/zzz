import {encode as tokenize} from 'gpt-tokenizer';
import {z} from 'zod';

import {Uuid, Datetime_Now} from '$lib/zod_helpers.js';
import {get_unique_name} from '$lib/helpers.js';
import {Bit, Bit_Json} from '$lib/bit.svelte.js';
import {reorder_list} from '$lib/list_helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {format_prompt_content} from '$lib/prompt_helpers.js';

export const PROMPT_CONTENT_TRUNCATED_LENGTH = 100;

export interface Prompt_Message {
	role: 'user' | 'system';
	content: Array<Prompt_Message_Content>;
}

export type Prompt_Message_Content = string; // TODO ?

const prompt_names: Array<string> = [];

export const Prompt_Json = Cell_Json.extend({
	id: Uuid,
	name: z.string().default(() => {
		// TODO BLOCK how to do this correctly? can you make it stateful and still have a static module-scoped schema? I dont see a context object arg or anything
		const name = get_unique_name('prompt', prompt_names);
		prompt_names.push(name);
		return name;
	}),
	created: Datetime_Now,
	bits: z.array(Bit_Json).default(() => []),
});
export type Prompt_Json = z.infer<typeof Prompt_Json>;

export interface Prompt_Options extends Cell_Options<typeof Prompt_Json> {
	name?: string;
}

export class Prompt extends Cell<typeof Prompt_Json> {
	name: string = $state()!;
	bits: Array<Bit> = $state()!;

	content: string = $derived(format_prompt_content(this.bits));

	length: number = $derived(this.content.length);
	tokens: Array<number> = $derived(tokenize(this.content)); // TODO @many eager computation in some UI cases is bad UX with large values (e.g. bottleneck typing)
	token_count: number = $derived(this.tokens.length);
	content_truncated: string = $derived(
		this.content.length > PROMPT_CONTENT_TRUNCATED_LENGTH
			? this.content.substring(0, PROMPT_CONTENT_TRUNCATED_LENGTH) + '...'
			: this.content,
	);

	constructor(options: Prompt_Options) {
		super(Prompt_Json, options);

		// If name is provided directly in options, use it
		if (options.name) {
			this.name = get_unique_name(
				options.name,
				this.zzz.prompts.items.map((p) => p.name),
			);
		}

		// Initialize from json
		this.init();
	}

	add_bit(content: string = '', name: string = 'new bit'): Bit {
		const bit = new Bit({
			zzz: this.zzz,
			json: {
				name: get_unique_name(
					name,
					this.bits.map((f) => f.name),
				),
				content,
			},
		});
		this.bits.push(bit);
		return bit;
	}

	update_bit(
		id: Uuid,
		updates: Partial<Pick<Bit, 'name' | 'content' | 'has_xml_tag' | 'xml_tag_name' | 'attributes'>>,
	): void {
		const bit = this.bits.find((f) => f.id === id);
		if (bit) {
			if (updates.name !== undefined) bit.name = updates.name;
			if (updates.content !== undefined) bit.content = updates.content;
			if (updates.has_xml_tag !== undefined) bit.has_xml_tag = updates.has_xml_tag;
			if (updates.xml_tag_name !== undefined) bit.xml_tag_name = updates.xml_tag_name;

			// If attributes are being updated directly, handle array replacement for reactivity
			if (updates.attributes !== undefined) {
				bit.attributes = [...updates.attributes]; // Force reactivity
			}
		}
	}

	remove_bit(id: Uuid): boolean {
		const index = this.bits.findIndex((f) => f.id === id);
		if (index !== -1) {
			this.bits.splice(index, 1);
			return true;
		}
		return false;
	}

	remove_all_bits(): void {
		this.bits = [];
	}

	reorder_bits(from_index: number, to_index: number): void {
		reorder_list(this.bits, from_index, to_index);
	}
}
