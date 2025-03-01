import {encode} from 'gpt-tokenizer';

import type {Zzz} from '$lib/zzz.svelte.js';
import {Uuid} from '$lib/uuid.js';
import {get_unique_name} from '$lib/helpers.js';
import {XML_TAG_NAME_DEFAULT} from '$lib/constants.js';
import {Bit} from '$lib/bit.svelte.js';
import {reorder_list} from '$lib/list_helpers.js';

export const PROMPT_CONTENT_TRUNCATED_LENGTH = 100;

export interface Prompt_Message {
	role: 'user' | 'system';
	content: Array<Prompt_Message_Content>;
}

export type Prompt_Message_Content = string; // TODO ?

export class Prompt {
	readonly id: Uuid = Uuid.parse(undefined);
	name: string = $state('');
	created: string = new Date().toISOString();
	bits: Array<Bit> = $state([]);

	zzz: Zzz;

	content: string = $derived(join_prompt_bits(this.bits));

	length: number = $derived(this.content.length);
	tokens: Array<number> = $derived(encode(this.content)); // TODO @many eager computation in some UI cases is bad UX with large values (e.g. bottleneck typing)
	token_count: number = $derived(this.tokens.length);
	content_truncated: string = $derived(
		this.content.length > PROMPT_CONTENT_TRUNCATED_LENGTH
			? this.content.substring(0, PROMPT_CONTENT_TRUNCATED_LENGTH) + '...'
			: this.content,
	);

	constructor(zzz: Zzz, name: string = 'new prompt') {
		this.zzz = zzz;
		this.name = get_unique_name(
			name,
			zzz.prompts.items.map((p) => p.name),
		);
	}

	add_bit(content: string = '', name: string = 'new bit'): Bit {
		const bit = new Bit({
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
