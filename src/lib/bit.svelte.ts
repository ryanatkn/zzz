// bit.svelte.ts

import {encode} from 'gpt-tokenizer';
import {z} from 'zod';

import {Serializable, type Serializable_Options} from '$lib/serializable.svelte.js';
import {Uuid} from '$lib/uuid.js';
import {Xml_Attribute} from '$lib/xml.js';
import type {Zzz} from '$lib/zzz.svelte.js';

export const Bit_Json = z
	.object({
		id: Uuid,
		name: z.string().default(''), // TODO maybe use zzz or something else in context to get a non-colliding default?
		has_xml_tag: z.boolean().default(false),
		xml_tag_name: z.string().default(''),
		attributes: z.array(Xml_Attribute).default(() => []),
		enabled: z.boolean().default(true),
		content: z.string().default(''),
	})
	.default({});
export type Bit_Json = z.infer<typeof Bit_Json>;

export interface Bit_Options extends Serializable_Options<typeof Bit_Json, Zzz> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Bit extends Serializable<z.output<typeof Bit_Json>, typeof Bit_Json, Zzz> {
	// Defaults for json properties are set in the schema and assigned via `to_json()`
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

	constructor(options: Bit_Options) {
		super(Bit_Json, options);

		// Call init after instance creation to safely initialize properties
		this.init();
	}

	add_attribute(partial?: z.input<typeof Xml_Attribute>): void {
		this.attributes.push(Xml_Attribute.parse(partial));
	}

	/**
	 * @returns `true` if the attribute was updated, `false` if the attribute was not found
	 */
	update_attribute(id: Uuid, updates: Partial<Omit<Xml_Attribute, 'id'>>): boolean {
		const attribute = this.attributes.find((a) => a.id === id);
		if (!attribute) return false;

		// Use Zod to validate the updates against the Xml_Attribute schema
		const validated_updates = Xml_Attribute.partial().omit({id: true}).parse(updates);

		// Apply only the validated updates
		Object.assign(attribute, validated_updates);
		return true;
	}

	remove_attribute(id: Uuid): void {
		const index = this.attributes.findIndex((a) => a.id === id);
		if (index !== -1) {
			this.attributes.splice(index, 1);
		}
	}
}
