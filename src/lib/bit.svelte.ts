// bit.svelte.ts

import {encode} from 'gpt-tokenizer';
import {z} from 'zod';

import type {Xml_Attribute} from '$lib/prompt.svelte.js';
import {Serializable} from '$lib/serializable.svelte.js';
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

// We don't need a custom options type anymore since everything is handled through json

// TODO BLOCK ERROR
// Type 'ZodObject<{ id: ZodDefault<ZodString>; name: ZodDefault<ZodString>; has_xml_tag: ZodDefault<ZodBoolean>; xml_tag_name: ZodDefault<...>; attributes: ZodDefault<...>; enabled: ZodDefault<...>; content: ZodDefault<...>; }, "strip", ZodTypeAny, { ...; }, { ...; }>' does not satisfy the constraint 'ZodType<{ id: string; name: string; has_xml_tag: boolean; xml_tag_name: string; attributes: { value: string; id: string; key: string; }[]; enabled: boolean; content: string; }, ZodTypeDef, { ...; }>'.
//   The types of '_input.id' are incompatible between these types.
//     Type 'string | undefined' is not assignable to type 'string'.
//       Type 'undefined' is not assignable to type 'string'.ts(2344)
export class Bit extends Serializable<Bit_Json, typeof Bit_Json> {
	// Fix the schema type by using a getter that returns the properly typed schema
	protected schema = Bit_Json;

	id: Uuid = $state()!;
	name: string = $state()!;
	has_xml_tag: boolean = $state()!;
	xml_tag_name: string = $state()!;
	attributes: Array<Xml_Attribute> = $state()!;
	enabled: boolean = $state()!;
	content: string = $state()!;

	// Derived properties
	length: number = $derived(this.content.length);
	tokens: Array<number> = $derived(encode(this.content));
	token_count: number = $derived(this.tokens.length);

	// Constructor is inherited from parent class, no need to override

	// JSON serialization and deserialization
	to_json(): Bit_Json {
		return this.schema.parse({
			id: this.id,
			name: this.name,
			has_xml_tag: this.has_xml_tag,
			xml_tag_name: this.xml_tag_name,
			attributes: this.attributes.map((attr) => ({...attr, id: attr.id})),
			enabled: this.enabled,
			content: this.content,
		});
	}

	set_json(value: Partial<Bit_Json>): void {
		// Parse through schema to ensure defaults and validation
		const parsed = this.schema.partial().parse(value);

		if (parsed.id !== undefined && this.id && parsed.id !== this.id) {
			console.warn('Cannot change id after initialization');
		} else if (parsed.id !== undefined) {
			this.id = parsed.id;
		}

		if (parsed.name !== undefined) this.name = parsed.name;
		if (parsed.has_xml_tag !== undefined) this.has_xml_tag = parsed.has_xml_tag;
		if (parsed.xml_tag_name !== undefined) this.xml_tag_name = parsed.xml_tag_name;
		if (parsed.enabled !== undefined) this.enabled = parsed.enabled;
		if (parsed.content !== undefined) this.content = parsed.content;

		if (parsed.attributes !== undefined) {
			this.attributes = parsed.attributes.map((attr) => ({
				id: attr.id,
				key: attr.key,
				value: attr.value,
			}));
		}
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

	// Static factory methods
	static create_default(): Bit {
		return new Bit();
	}

	static from_json(json: Partial<Bit_Json>): Bit {
		return new Bit({json});
	}
}
