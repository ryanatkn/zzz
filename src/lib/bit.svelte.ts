import {encode as tokenize} from 'gpt-tokenizer';
import {z} from 'zod';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';
import {DEV} from 'esm-env';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Xml_Attribute} from '$lib/xml.js';
import {Cell_Json} from '$lib/cell_types.js';
import type {Diskfile} from '$lib/diskfile.svelte.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {Diskfile_Path} from '$lib/diskfile_types.js';
import {CONTENT_PREVIEW_LENGTH} from '$lib/constants.js';

/** Common properties for all bit types. */
export const Bit_Base_Json = Cell_Json.extend({
	type: z.string(), // Discriminator field for the type of bit
	name: z.string().default(''),
	start: z.number().nullable().default(null),
	end: z.number().nullable().default(null),
	has_xml_tag: z.boolean().default(false),
	xml_tag_name: z.string().default(''), // TODO @many move to the prompt somewhere
	attributes: z.array(Xml_Attribute).default(() => []), // TODO @many move to the prompt somewhere
	enabled: z.boolean().default(true),
	title: z.string().nullable().default(null),
	summary: z.string().nullable().default(null),
});
export type Bit_Base_Json = z.infer<typeof Bit_Base_Json>;

/** Text bit schema - direct content storage. */
export const Text_Bit_Json = Bit_Base_Json.extend({
	type: z.literal('text').default('text'),
	content: z.string().default(''),
});
export type Text_Bit_Json = z.infer<typeof Text_Bit_Json>;

/** Diskfile bit schema - references a diskfile. */
export const Diskfile_Bit_Json = Bit_Base_Json.extend({
	type: z.literal('diskfile').default('diskfile'),
	path: Diskfile_Path.nullable().default(null),
	has_xml_tag: Bit_Base_Json.shape.has_xml_tag.default(true), // Override to make true only for diskfiles
	// `content` is on disk at `path`, not in the serialized representation
});
export type Diskfile_Bit_Json = z.infer<typeof Diskfile_Bit_Json>;

/** Sequence bit schema - contains an ordered list of bit references. */
export const Sequence_Bit_Json = Bit_Base_Json.extend({
	type: z.literal('sequence').default('sequence'),
	items: z.array(Uuid).default(() => []),
});
export type Sequence_Bit_Json = z.infer<typeof Sequence_Bit_Json>;

/** Union of all bit types for deserialization. */
export const Bit_Json = z.discriminatedUnion('type', [
	Text_Bit_Json, // TODO consider renaming this to or adding `Resource_Bit_Json` like MCP (text+binary)
	Diskfile_Bit_Json,
	Sequence_Bit_Json,
]);
export type Bit_Json = z.infer<typeof Bit_Json>;

// Define a type union of all concrete bit classes
export type Bit_Type = Text_Bit | Diskfile_Bit | Sequence_Bit;
export type Bit_Json_Type = Text_Bit_Json | Diskfile_Bit_Json | Sequence_Bit_Json;

// Base options interface - fixed to properly constrain the type parameter
export interface Bit_Options<T extends z.ZodType = typeof Bit_Base_Json> extends Cell_Options<T> {
	json?: z.input<T>;
}

// Specific options types for each bit type
export type Text_Bit_Options = Bit_Options<typeof Text_Bit_Json>;

export type Diskfile_Bit_Options = Bit_Options<typeof Diskfile_Bit_Json>;

export type Sequence_Bit_Options = Bit_Options<typeof Sequence_Bit_Json>;

export type Bit_Type_Options = Text_Bit_Options | Diskfile_Bit_Options | Sequence_Bit_Options;

/**
 * Abstract base class for all bit types.
 */
export abstract class Bit<T extends z.ZodType = typeof Bit_Base_Json> extends Cell<T> {
	// The type discriminator - to be set by subclasses
	abstract readonly type: string;

	abstract get content(): string | null | undefined;

	start: number | null = $state()!;
	end: number | null = $state()!;
	length: number | null | undefined = $derived.by(() => this.content?.length);
	tokens: Array<number> | null | undefined = $derived.by(() =>
		this.content == null ? this.content : tokenize(this.content),
	);
	token_count: number | null | undefined = $derived(this.tokens?.length);
	/** `content` with a max length */
	content_preview = $derived.by(() =>
		this.content && this.content.length > CONTENT_PREVIEW_LENGTH
			? this.content.substring(0, CONTENT_PREVIEW_LENGTH)
			: this.content,
	);

	// Common properties for all bit types
	name: string = $state()!;
	has_xml_tag: boolean = $state()!;
	xml_tag_name: string = $state()!;
	attributes: Array<Xml_Attribute> = $state()!;
	enabled: boolean = $state()!;
	title: string | null = $state()!;
	summary: string | null = $state()!;

	default_xml_tag_name: string = $derived.by(() =>
		this.type === 'diskfile' ? 'file' : 'fragment',
	);

	add_attribute(partial: z.input<typeof Xml_Attribute> = EMPTY_OBJECT): void {
		this.attributes.push(Xml_Attribute.parse(partial));
	}

	/**
	 * @returns `true` if the attribute was updated, `false` if the attribute was not found
	 */
	update_attribute(id: Uuid, updates: Partial<Omit<Xml_Attribute, 'id'>>): boolean {
		// Find the attribute by id
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

	// TODO can this be automated with the schema somehow? probs
	/**
	 * Create a bit of any type.
	 *
	 * This is the unified entry point for bit creation that handles:
	 * 1. Type discrimination from JSON
	 * 2. Default values
	 * 3. Construction of the appropriate bit subclass via the registry
	 */
	static create(
		zzz: Zzz,
		json: z.input<typeof Text_Bit_Json>,
		options?: Text_Bit_Options,
	): Text_Bit;
	static create(
		zzz: Zzz,
		json: z.input<typeof Diskfile_Bit_Json>,
		options?: Diskfile_Bit_Options,
	): Diskfile_Bit;
	static create(
		zzz: Zzz,
		json: z.input<typeof Sequence_Bit_Json>,
		options?: Sequence_Bit_Options,
	): Sequence_Bit;
	static create(
		zzz: Zzz,
		json: z.input<typeof Bit_Json>,
		options?: Bit_Options<z.ZodTypeAny>,
	): Bit_Type {
		if (!json.type) {
			throw new Error('Missing required "type" field in bit JSON');
		}

		// Create the appropriate bit class based on type using the registry
		// This throws if the class isn't registered, ensuring we fail fast
		// on any programming errors rather than silently returning null
		switch (json.type) {
			case 'text':
				return zzz.registry.instantiate('Text_Bit', json, options);
			case 'diskfile':
				return zzz.registry.instantiate('Diskfile_Bit', json, options);
			case 'sequence':
				return zzz.registry.instantiate('Sequence_Bit', json, options);
			default:
				throw new Unreachable_Error(json.type);
		}
	}
}

export const Bit_Schema = z.instanceof(Bit);

/**
 * Text bit - stores content directly.
 */
export class Text_Bit extends Bit<typeof Text_Bit_Json> {
	override readonly type = 'text';

	// Direct content storage
	override content: string = $state()!;

	constructor(options: Text_Bit_Options) {
		super(Text_Bit_Json, options);
		this.init();
	}
}

export const Text_Bit_Schema = z.instanceof(Text_Bit);

/**
 * Diskfile bit - references content from a Diskfile.
 */
export class Diskfile_Bit extends Bit<typeof Diskfile_Bit_Json> {
	override readonly type = 'diskfile';

	/** Path property with private backing field */
	#path: Diskfile_Path | null = $state()!;

	/**
	 * Writable value that determines `this.diskfile`.
	 * Also includes special diskfile bit logic for attributes.
	 */
	get path(): Diskfile_Path | null {
		return this.#path;
	}

	set path(value: Diskfile_Path | null) {
		this.#path = value;

		if (value === null) return;

		// Update the path attribute when the path changes
		const diskfile = this.zzz.diskfiles.get_by_path(value);
		const relative_path = diskfile?.path_relative;

		if (!relative_path) return;

		// Check if a path attribute already exists
		const path_attr_index = this.attributes.findIndex((attr) => attr.key.trim() === 'path');

		if (path_attr_index >= 0) {
			// Update existing path attribute
			const new_attributes = [...this.attributes];
			new_attributes[path_attr_index].value = relative_path;
			this.attributes = new_attributes;
		} else {
			// Add new path attribute
			this.add_attribute({
				key: 'path',
				value: relative_path,
			});
		}
	}

	// Reference to the editor state for this bit
	#editor_state: {current_content: string} | null = $state(null); // TODO @many this initialization is awkward, ideally becomes refactored to mostly derived

	diskfile: Diskfile | null | undefined = $derived(
		this.path && this.zzz.diskfiles.get_by_path(this.path),
	);

	// The current relative path value for display in the XML path attribute
	relative_path = $derived(this.diskfile?.path_relative);

	override get content(): string | null | undefined {
		// Return editor content if available, otherwise fall back to diskfile content
		return this.#editor_state?.current_content ?? this.diskfile?.content; // TODO @many this initialization is awkward, ideally becomes refactored to mostly derived
	}

	set content(value: string | null | undefined) {
		if (value == null) {
			if (DEV) console.error(`Cannot set diskfile content to ${value}`);
			return;
		}

		if (this.path) {
			this.zzz.diskfiles.update(this.path, value);
		}
	}

	constructor(options: Diskfile_Bit_Options) {
		super(Diskfile_Bit_Json, options);
		this.init();
	}

	// TODO @many this initialization is awkward, ideally becomes refactored to mostly derived
	/**
	 * Links this bit to an editor state.
	 */
	link_editor_state(editor_state: {current_content: string} | null): void {
		this.#editor_state = editor_state;
	}
}

export const Diskfile_Bit_Schema = z.instanceof(Diskfile_Bit);

/**
 * Sequence bit - contains an ordered list of bit references.
 */
export class Sequence_Bit extends Bit<typeof Sequence_Bit_Json> {
	override readonly type = 'sequence';

	items: Array<Uuid> = $state()!;

	bits: Array<Bit_Type> = $derived(
		this.items
			.map((id) => this.zzz.bits.items.by_id.get(id))
			.filter((bit): bit is Bit_Type => !!bit),
	);

	override get content(): string {
		return this.bits.map((bit) => bit.content).join('\n\n');
	}

	set content(value: string) {
		if (DEV) {
			console.error(
				'Cannot directly update content for sequence bits as it is derived from referenced bits',
				value,
			);
		}
	}

	constructor(options: Sequence_Bit_Options) {
		super(Sequence_Bit_Json, options);
		this.init();
	}

	/**
	 * Add a bit to the sequence.
	 * @returns `true` if the bit was added, `false` if it was already in the sequence
	 */
	add(bit_id: Uuid): boolean {
		if (this.items.includes(bit_id)) return false;
		this.items.push(bit_id);
		return true;
	}

	/**
	 * Remove a bit from the sequence.
	 * @returns `true` if the bit was removed, `false` if it wasn't in the sequence
	 */
	remove(bit_id: Uuid): boolean {
		const index = this.items.findIndex((id) => id === bit_id);
		if (index === -1) return false;

		this.items.splice(index, 1);
		return true;
	}

	/**
	 * Move a bit to a new position in the sequence.
	 * @returns `true` if the bit was moved, `false` if it wasn't in the sequence
	 */
	move(bit_id: Uuid, new_index: number): boolean {
		const current_index = this.items.findIndex((id) => id === bit_id);
		if (current_index === -1) return false;

		const item_to_move = this.items[current_index];
		this.items.splice(current_index, 1);
		this.items.splice(new_index, 0, item_to_move);
		return true;
	}
}

export const Sequence_Bit_Schema = z.instanceof(Sequence_Bit);
