import {encode} from 'gpt-tokenizer';
import {z} from 'zod';

import {Uuid} from '$lib/uuid.js';
import {get_unique_name} from '$lib/helpers.js';
import {XML_TAG_NAME_DEFAULT} from '$lib/constants.js';
import {Bit, Bit_Json} from '$lib/bit.svelte.js';
import {reorder_list} from '$lib/list_helpers.js';
import {Serializable, type Serializable_Options} from '$lib/serializable.svelte.js';

export const PROMPT_CONTENT_TRUNCATED_LENGTH = 100;

export interface Prompt_Message {
	role: 'user' | 'system';
	content: Array<Prompt_Message_Content>;
}

export type Prompt_Message_Content = string; // TODO ?

const prompt_names: Array<string> = [];

export const Prompt_Json = z
	.object({
		id: Uuid,
		name: z.string().default(() => {
			// TODO BLOCK how to do this correctly? can you make it stateful and still have a static module-scoped schema? I dont see a context object arg or anything
			const name = get_unique_name('prompt', prompt_names);
			prompt_names.push(name);
			return name;
		}),
		created: z
			.string()
			.datetime()
			.default(() => new Date().toISOString()),
		bits: z.array(Bit_Json).default(() => []),
	})
	.default(() => ({}));
export type Prompt_Json = z.infer<typeof Prompt_Json>;

export interface Prompt_Options extends Serializable_Options<typeof Prompt_Json> {
	name?: string;
}

export class Prompt extends Serializable<typeof Prompt_Json> {
	id: Uuid = $state()!;
	name: string = $state()!;
	created: string = $state()!;
	bits: Array<Bit> = $state()!;

	content: string = $derived(join_prompt_bits(this.bits));

	length: number = $derived(this.content.length);
	tokens: Array<number> = $derived(encode(this.content)); // TODO @many eager computation in some UI cases is bad UX with large values (e.g. bottleneck typing)
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
		updates: Partial<Pick<Bit, 'name' | 'content' | 'has_xml_tag' | 'xml_tag_name'>>,
	): void {
		const bit = this.bits.find((f) => f.id === id);
		if (bit) {
			if (updates.name !== undefined) bit.name = updates.name;
			if (updates.content !== undefined) bit.content = updates.content;
			if (updates.has_xml_tag !== undefined) bit.has_xml_tag = updates.has_xml_tag;
			if (updates.xml_tag_name !== undefined) bit.xml_tag_name = updates.xml_tag_name;
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

	// Additional methods to deserialize bit arrays for compatibility
	set_bits_from_json(bit_jsons: Array<Bit_Json>): void {
		this.bits = bit_jsons.map((json) => new Bit({zzz: this.zzz, json}));
	}
}

export const join_prompt_bits = (bits: Array<Bit>): string =>
	bits
		.filter((f) => f.enabled)
		.map((f) => {
			const content = f.content.trim();
			if (!content) return '';
			if (!f.has_xml_tag) return content;

			const xml_tag_name = f.xml_tag_name.trim() || XML_TAG_NAME_DEFAULT;

			const attrs = f.attributes
				.filter((a) => a.key && a.value)
				.map((a) => ` ${a.key}="${a.value}"`) // TODO any encoding?
				.join('');

			return `<${xml_tag_name}${attrs}>\n${content}\n</${xml_tag_name}>`;
		})
		.filter((c) => !!c)
		.join('\n\n');
