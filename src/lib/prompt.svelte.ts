import {encode} from 'gpt-tokenizer';

import type {Zzz} from '$lib/zzz.svelte.js';
import {random_id, type Id} from '$lib/id.js';
import {get_unique_name} from '$lib/helpers.js';
import {XML_TAG_NAME_DEFAULT} from '$lib/constants.js';
import {Bit} from '$lib/bit.svelte.js';

export interface Prompt_Message {
	role: 'user' | 'system';
	content: Array<Prompt_Message_Content>;
}

export type Prompt_Message_Content = string; // TODO ?

export class Prompt {
	readonly id: Id = random_id();
	name: string = $state('');
	created: string = new Date().toISOString();
	bits: Array<Bit> = $state([]);

	zzz: Zzz;

	content: string = $derived(join_prompt_bits(this.bits));

	length: number = $derived(this.content.length);
	tokens: Array<number> = $derived(encode(this.content)); // TODO @many eager computation in some UI cases is bad UX with large values (e.g. bottleneck typing)
	token_count: number = $derived(this.tokens.length);

	constructor(zzz: Zzz, name: string = 'new prompt') {
		this.zzz = zzz;
		this.name = get_unique_name(
			name,
			zzz.prompts.items.map((p) => p.name),
		);
	}

	add_bit(content: string = '', name: string = 'new bit'): Bit {
		const bit = new Bit(
			get_unique_name(
				name,
				this.bits.map((f) => f.name),
			),
			content,
		);
		this.bits.push(bit);
		return bit;
	}

	update_bit(
		id: Id,
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

	remove_bit(id: Id): boolean {
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

export interface Xml_Attribute {
	id: Id;
	key: string;
	value: string;
}
