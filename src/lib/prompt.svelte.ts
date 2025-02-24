import type {Zzz} from '$lib/zzz.svelte.js';
import {random_id, type Id} from '$lib/id.js';

const XML_TAG_NAME_DEFAULT = 'content'; // TODO config

export interface Prompt_Message {
	role: 'user' | 'system';
	content: Array<Prompt_Message_Content>;
}

export type Prompt_Message_Content = string; // TODO ?

export class Prompt {
	readonly id: Id = random_id();
	name: string = $state('new prompt');
	created: string = new Date().toISOString();
	fragments: Array<Prompt_Fragment> = $state([]);

	zzz: Zzz;

	value: string = $derived(join_prompt_fragments(this.fragments));
	length: number = $derived(this.value.length); // TODO use segmenter for more precision? will it be slow for large values tho?
	token_count: number = $derived(count_tokens(this.value));

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	add_fragment(content: string = '', name: string = 'new fragment'): Prompt_Fragment {
		const fragment = new Prompt_Fragment(name, content);
		this.fragments.push(fragment);
		return fragment;
	}

	update_fragment(
		id: Id,
		updates: Partial<Pick<Prompt_Fragment, 'name' | 'content' | 'has_xml_tag' | 'xml_tag_name'>>,
	): void {
		const fragment = this.fragments.find((f) => f.id === id);
		if (fragment) {
			if (updates.name !== undefined) fragment.name = updates.name;
			if (updates.content !== undefined) fragment.content = updates.content;
			if (updates.has_xml_tag !== undefined) fragment.has_xml_tag = updates.has_xml_tag;
			if (updates.xml_tag_name !== undefined) fragment.xml_tag_name = updates.xml_tag_name;
		}
	}

	remove_fragment(id: Id): boolean {
		const index = this.fragments.findIndex((f) => f.id === id);
		if (index !== -1) {
			this.fragments.splice(index, 1);
			return true;
		}
		return false;
	}

	remove_all_fragments(): void {
		this.fragments = [];
	}
}

export const join_prompt_fragments = (fragments: Array<Prompt_Fragment>): string =>
	fragments
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

// TODO use a tokenizer
export const count_tokens = (text: string): number => Math.round(text.length / 4);

export interface Xml_Attribute {
	id: Id;
	key: string;
	value: string;
}

// TODO maybe rename to just `Fragment`? extract to `fragment.svelte.ts`?
export class Prompt_Fragment {
	readonly id: Id = random_id();
	name: string = $state('');
	content: string = $state('');
	has_xml_tag: boolean = $state(false);
	xml_tag_name: string = $state('');
	attributes: Array<Xml_Attribute> = $state([]);
	enabled: boolean = $state(true);

	length: number = $derived(this.content.length); // TODO use segmenter for more precision? will it be slow for large contents tho?
	token_count: number = $derived(count_tokens(this.content));

	constructor(name: string = 'new fragment', content: string = '') {
		this.name = name;
		this.content = content;
	}

	// TODO defaults/partial?
	add_attribute(): void {
		const attr: Xml_Attribute = {
			id: random_id(),
			key: '',
			value: '',
		};
		this.attributes.push(attr);
	}

	update_attribute(id: Id, updates: Partial<Omit<Xml_Attribute, 'id'>>): void {
		const index = this.attributes.findIndex((a) => a.id === id);
		if (index === -1) return;

		const attribute = this.attributes[index];
		const final_updates: Partial<Omit<Xml_Attribute, 'id'>> = {...updates};

		// Only check for duplicates if the new key is non-empty
		if (updates.key !== undefined && updates.key !== attribute.key && updates.key !== '') {
			let key = updates.key;
			let counter = 1;
			while (this.attributes.some((a) => a.id !== id && a.key === key)) {
				key = `${updates.key}${counter}`;
				counter++;
			}
			final_updates.key = key;
		}

		Object.assign(attribute, final_updates);
	}

	remove_attribute(id: Id): void {
		const index = this.attributes.findIndex((a) => a.id === id);
		if (index !== -1) {
			this.attributes.splice(index, 1);
		}
	}
}
