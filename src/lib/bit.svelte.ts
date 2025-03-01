// bit.svelte.ts

import {encode} from 'gpt-tokenizer';
import type {Json_Object} from '@ryanatkn/belt/json.js';

import {random_id, type Id} from '$lib/id.js';
import type {Xml_Attribute} from '$lib/prompt.svelte.js';
import {Serializable} from '$lib/serializable.svelte.js';

export interface Bit_Json extends Json_Object {
	id: string;
	name: string;
	has_xml_tag: boolean;
	xml_tag_name: string;
	attributes: Array<Omit<Xml_Attribute, 'id'> & {id: string}>;
	enabled: boolean;
	content: string;
}

export class Bit extends Serializable<Bit_Json> {
	readonly id: Id = random_id();
	name: string = $state('');
	has_xml_tag: boolean = $state(false);
	xml_tag_name: string = $state('');
	attributes: Array<Xml_Attribute> = $state([]);
	enabled: boolean = $state(true);

	content: string = $state('');
	length: number = $derived(this.content.length);
	tokens: Array<number> = $derived(encode(this.content)); // TODO @many eager computation in some UI cases is bad UX with large values (e.g. bottleneck typing)
	token_count: number = $derived(this.tokens.length);

	constructor(name: string = 'new bit', content: string = '') {
		super();
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

	to_json(): Bit_Json {
		return {
			id: this.id,
			name: this.name,
			has_xml_tag: this.has_xml_tag,
			xml_tag_name: this.xml_tag_name,
			attributes: this.attributes.map((attr) => ({...attr, id: attr.id})),
			enabled: this.enabled,
			content: this.content,
		};
	}

	set_json(value: Partial<Bit_Json>): void {
		if (value.name !== undefined) this.name = value.name;
		if (value.has_xml_tag !== undefined) this.has_xml_tag = value.has_xml_tag;
		if (value.xml_tag_name !== undefined) this.xml_tag_name = value.xml_tag_name;
		if (value.enabled !== undefined) this.enabled = value.enabled;
		if (value.content !== undefined) this.content = value.content;

		if (value.attributes !== undefined) {
			this.attributes = value.attributes.map((attr) => ({
				id: attr.id,
				key: attr.key,
				value: attr.value,
			}));
		}
	}
}
