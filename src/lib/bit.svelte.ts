import {encode as tokenize} from 'gpt-tokenizer';
import {z} from 'zod';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Xml_Attribute} from '$lib/xml.js';
import {Cell_Json} from '$lib/cell_types.js';

export const Bit_Json = Cell_Json.extend({
	id: Uuid,
	name: z.string().default(''), // TODO maybe use zzz or something else in context to get a non-colliding default?
	has_xml_tag: z.boolean().default(false),
	xml_tag_name: z.string().default(''),
	attributes: z.array(Xml_Attribute).default(() => []),
	enabled: z.boolean().default(true),
	content: z.string().default(''),
});
export type Bit_Json = z.infer<typeof Bit_Json>;

export interface Bit_Options extends Cell_Options<typeof Bit_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Bit extends Cell<typeof Bit_Json> {
	// Defaults for json properties are set in the schema and assigned via `to_json()`
	name: string = $state()!;
	has_xml_tag: boolean = $state()!;
	xml_tag_name: string = $state()!;
	attributes: Array<Xml_Attribute> = $state()!;
	enabled: boolean = $state()!;
	content: string = $state()!;

	length: number = $derived(this.content.length);
	tokens: Array<number> = $derived(tokenize(this.content));
	token_count: number = $derived(this.tokens.length);

	constructor(options: Bit_Options) {
		super(Bit_Json, options);

		// Call init after instance creation to safely initialize properties
		this.init();
	}

	add_attribute(partial: z.input<typeof Xml_Attribute> = EMPTY_OBJECT): void {
		this.attributes.push(Xml_Attribute.parse(partial));
	}

	/**
	 * @returns `true` if the attribute was updated, `false` if the attribute was not found
	 */
	update_attribute(id: Uuid, updates: Partial<Omit<Xml_Attribute, 'id'>>): boolean {
		// Find the attribute by ID
		const index = this.attributes.findIndex((a) => a.id === id);
		if (index === -1) return false;

		// Create a new attributes array to ensure reactivity
		const new_attributes = [...this.attributes];

		// Get the attribute to update
		const attr = new_attributes[index];

		// Apply updates directly
		if ('key' in updates && updates.key !== undefined) {
			attr.key = updates.key;
		}

		if ('value' in updates && updates.value !== undefined) {
			attr.value = updates.value;
		}

		// Replace the entire array to ensure reactivity
		this.attributes = new_attributes;

		return true;
	}

	remove_attribute(id: Uuid): void {
		const index = this.attributes.findIndex((a) => a.id === id);
		if (index !== -1) {
			this.attributes.splice(index, 1);
		}
	}
}
