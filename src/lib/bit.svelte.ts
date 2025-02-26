import {encode} from 'gpt-tokenizer';

import {random_id, type Id} from '$lib/id.js';
import type {Xml_Attribute} from '$lib/prompt.svelte.js';

export class Bit {
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
