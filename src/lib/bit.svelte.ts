// bit.svelte.ts

import {encode} from 'gpt-tokenizer';
import {z} from 'zod';

import type {Xml_Attribute} from '$lib/prompt.svelte.js';
import {Serializable, type Serializable_Options} from '$lib/serializable.svelte.js';
import {Uuid} from '$lib/uuid.js';

export const Bit_Attribute = z.object({
	id: Uuid,
	key: z.string().default(''),
	value: z.string().default(''),
});
export type Bit_Attribute = z.infer<typeof Bit_Attribute>;

export const Bit_Json = z.object({
	id: Uuid,
	name: z.string().default('new bit'),
	has_xml_tag: z.boolean().default(false),
	xml_tag_name: z.string().default(''),
	attributes: z.array(Bit_Attribute).default([]),
	enabled: z.boolean().default(true),
	content: z.string().default(''),
});
export type Bit_Json = z.infer<typeof Bit_Json>;
export type Bit_Json_Input = z.input<typeof Bit_Json>; // TODO BLOCK use these
export type Bit_Json_Output = z.output<typeof Bit_Json>; // TODO BLOCK use these

export class Bit extends Serializable<Bit_Json_Output, typeof Bit_Json> {
	id: Uuid = $state()!;
	name: string = $state()!;
	has_xml_tag: boolean = $state()!;
	xml_tag_name: string = $state()!;
	attributes: Array<Xml_Attribute> = $state()!;
	enabled: boolean = $state()!;
	content: string = $state()!;

	length: number = $derived(this.content.length);
	tokens: Array<number> = $derived(encode(this.content));
	token_count: number = $derived(this.tokens.length);

	constructor(options?: Serializable_Options<Bit_Json_Output>) {
		super(Bit_Json);

		if (options?.json) {
			this.set_json(options.json);
		}
	}

	static create_default(): Bit {
		return new Bit();
	}

	static from_json(json: Partial<Bit_Json>): Bit {
		return new Bit({json});
	}

	to_json(): Bit_Json {
		return this.schema.parse({
			id: this.id,
			name: this.name,
			has_xml_tag: this.has_xml_tag,
			xml_tag_name: this.xml_tag_name,
			attributes: $state.snapshot(this.attributes),
			enabled: this.enabled,
			content: this.content,
		});
	}

	set_json(value: z.input<typeof Bit_Json>): void {
		const parsed = this.schema.parse(value);

		this.id = parsed.id;
		this.name = parsed.name;
		this.has_xml_tag = parsed.has_xml_tag;
		this.xml_tag_name = parsed.xml_tag_name;
		this.attributes = parsed.attributes.map((attr) => ({
			id: attr.id,
			key: attr.key,
			value: attr.value,
		}));
		this.enabled = parsed.enabled;
		this.content = parsed.content;
	}

	// Attribute management methods
	add_attribute(partial?: Partial<Omit<Bit_Attribute, 'id'>>): void {
		// Use the schema to create a new attribute with proper defaults
		const attr = Bit_Attribute.parse({
			...partial,
			// Always generate a new ID regardless of what might be in partial
			id: Uuid.parse(undefined), // This will use the default UUID generator
		});

		this.attributes.push(attr);
	}

	update_attribute(id: Uuid, updates: Partial<Omit<Xml_Attribute, 'id'>>): void {
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

	remove_attribute(id: Uuid): void {
		const index = this.attributes.findIndex((a) => a.id === id);
		if (index !== -1) {
			this.attributes.splice(index, 1);
		}
	}
}
