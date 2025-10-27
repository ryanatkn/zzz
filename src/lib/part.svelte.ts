import {z} from 'zod';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';
import {DEV} from 'esm-env';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';
import type {Omit_Strict} from '@ryanatkn/belt/types.js';

import {estimate_token_count} from '$lib/helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Xml_Attribute_With_Defaults} from '$lib/xml.js';
import {Cell_Json} from '$lib/cell_types.js';
import type {Diskfile} from '$lib/diskfile.svelte.js';
import type {Frontend} from '$lib/frontend.svelte.js';
import {Diskfile_Path} from '$lib/diskfile_types.js';
import {CONTENT_PREVIEW_LENGTH} from '$lib/constants.js';

/** Common properties for all part types. */
export const Part_Json_Base = Cell_Json.extend({
	type: z.string(),
	name: z.string().default(''),
	start: z.number().nullable().default(null),
	end: z.number().nullable().default(null),
	has_xml_tag: z.boolean().default(false),
	xml_tag_name: z.string().default(''), // TODO @many move to the prompt somewhere
	attributes: z.array(Xml_Attribute_With_Defaults).default(() => []), // TODO @many move to the prompt somewhere
	// TODO should maybe be swapped to `disabled`
	enabled: z.boolean().default(true),
	title: z.string().nullable().default(null),
	summary: z.string().nullable().default(null),
});
export type Part_Json_Base = z.infer<typeof Part_Json_Base>;

/** Text part schema - direct content storage. */
export const Text_Part_Json = Part_Json_Base.extend({
	type: z.literal('text').default('text'),
	content: z.string().default(''),
});
export type Text_Part_Json = z.infer<typeof Text_Part_Json>;
export type Text_Part_Json_Input = z.input<typeof Text_Part_Json>;

/** Diskfile part schema - references a diskfile. */
export const Diskfile_Part_Json = Part_Json_Base.extend({
	type: z.literal('diskfile').default('diskfile'),
	path: Diskfile_Path.nullable().default(null),
	has_xml_tag: Part_Json_Base.shape.has_xml_tag.default(true), // Override to make true only for diskfiles
	// `content` is on disk at `path`, not in the serialized representation
});
export type Diskfile_Part_Json = z.infer<typeof Diskfile_Part_Json>;
export type Diskfile_Part_Json_Input = z.input<typeof Diskfile_Part_Json>;

/** Union of all part types for deserialization. */
export const Part_Json = z
	.discriminatedUnion('type', [Text_Part_Json, Diskfile_Part_Json])
	.meta({cell_class_name: 'Part'});
export type Part_Json = z.infer<typeof Part_Json>;
export type Part_Json_Input = z.input<typeof Part_Json>;

export type Part_Union = Text_Part | Diskfile_Part;
export type Part_Json_Type = Text_Part_Json | Diskfile_Part_Json;

export interface Part_Options<T extends z.ZodType = typeof Part_Json_Base> extends Cell_Options<T> {
	json?: z.input<T>;
}

export type Text_Part_Options = Part_Options<typeof Text_Part_Json>;
export type Diskfile_Part_Options = Part_Options<typeof Diskfile_Part_Json>;
export type Part_Options_Union = Text_Part_Options | Diskfile_Part_Options;

/**
 * Abstract base class for all part types.
 */
export abstract class Part<T extends z.ZodType = typeof Part_Json_Base> extends Cell<T> {
	// The type discriminator - to be set by subclasses
	abstract readonly type: string;

	abstract get content(): string | null | undefined;

	start: number | null = $state()!;
	end: number | null = $state()!;
	readonly length: number | null | undefined = $derived.by(() => this.content?.length);
	readonly token_count: number | null | undefined = $derived.by(() =>
		this.content == null ? this.content : estimate_token_count(this.content),
	);
	/** `content` with a max length */
	readonly content_preview = $derived.by(() =>
		this.content && this.content.length > CONTENT_PREVIEW_LENGTH
			? this.content.substring(0, CONTENT_PREVIEW_LENGTH)
			: this.content,
	);

	// TODO rethink these patterns, see A2A Parts
	// Common properties for all part types
	name: string = $state()!;
	has_xml_tag: boolean = $state()!;
	xml_tag_name: string = $state()!;
	attributes: Array<Xml_Attribute_With_Defaults> = $state()!; // TODO if kept, name `xml_attributes`?
	enabled: boolean = $state()!;
	title: string | null = $state()!;
	summary: string | null = $state()!;

	readonly xml_tag_name_default: string = $derived.by(() =>
		this.type === 'diskfile' ? 'File' : 'Fragment',
	);

	add_attribute(partial: z.input<typeof Xml_Attribute_With_Defaults> = EMPTY_OBJECT): void {
		// TODO add with a default name
		this.attributes.push(Xml_Attribute_With_Defaults.parse(partial));
	}

	/**
	 * @returns `true` if the attribute was updated, `false` if the attribute was not found
	 */
	update_attribute(
		id: Uuid,
		updates: Partial<Omit_Strict<Xml_Attribute_With_Defaults, 'id'>>,
	): boolean {
		// Find the attribute by id
		const index = this.attributes.findIndex((a) => a.id === id);
		if (index === -1) return false;

		// TODO refactor this code, maybe update directly? using svelte 5 idioms
		const new_attributes = [...this.attributes];

		const attr = new_attributes[index]!; // guaranteed by index !== -1 check above

		if ('key' in updates && updates.key !== undefined) {
			attr.key = updates.key;
		}

		if ('value' in updates && updates.value !== undefined) {
			attr.value = updates.value;
		}

		this.attributes = new_attributes;

		return true;
	}

	remove_attribute(id: Uuid): void {
		const index = this.attributes.findIndex((a) => a.id === id);
		if (index !== -1) {
			this.attributes.splice(index, 1);
		}
	}

	static create(app: Frontend, json: Text_Part_Json_Input, options?: Text_Part_Options): Text_Part;
	static create(
		app: Frontend,
		json: Diskfile_Part_Json_Input,
		options?: Diskfile_Part_Options,
	): Diskfile_Part;
	static create(app: Frontend, json: Part_Json_Input, options?: Part_Options_Union): Part_Union;
	static create(app: Frontend, json: Part_Json_Input, options?: Part_Options_Union): Part_Union {
		if (!json.type) {
			throw new Error('Missing required "type" field in part JSON');
		}

		switch (json.type) {
			case 'text':
				return new Text_Part({...options, app, json});
			case 'diskfile':
				return new Diskfile_Part({...options, app, json});
			default:
				throw new Unreachable_Error(json.type);
		}
	}
}

export const Part_Schema = z.instanceof(Part);

/**
 * Text part - stores content directly.
 */
export class Text_Part extends Part<typeof Text_Part_Json> {
	override readonly type = 'text';

	override content: string = $state()!;

	constructor(options: Text_Part_Options) {
		super(Text_Part_Json, options);
		this.init();
	}
}

export const Text_Part_Schema = z.instanceof(Text_Part);

/**
 * Diskfile part - references content from a Diskfile.
 */
export class Diskfile_Part extends Part<typeof Diskfile_Part_Json> {
	override readonly type = 'diskfile';

	/** Path property with private backing field */
	#path: Diskfile_Path | null = $state()!;

	/**
	 * Writable value that determines `this.diskfile`.
	 * Also includes special diskfile part logic for attributes.
	 */
	get path(): Diskfile_Path | null {
		return this.#path;
	}

	set path(value: Diskfile_Path | null) {
		this.#path = value;

		if (value === null) return;

		// Update the path attribute when the path changes
		const diskfile = this.app.diskfiles.get_by_path(value);
		const relative_path = diskfile?.path_relative;

		if (!relative_path) return;

		// Check if a path attribute already exists
		const path_attr_index = this.attributes.findIndex((attr) => attr.key.trim() === 'path');

		if (path_attr_index >= 0) {
			// Update existing path attribute
			const new_attributes = [...this.attributes];
			new_attributes[path_attr_index]!.value = relative_path; // guaranteed by >= 0 check
			this.attributes = new_attributes;
		} else {
			// Add new path attribute
			this.add_attribute({
				key: 'path',
				value: relative_path,
			});
		}
	}

	// Reference to the editor state for this part
	#editor_state: {current_content: string} | null = $state(null); // TODO @many this initialization is awkward, ideally becomes refactored to mostly derived

	readonly diskfile: Diskfile | null | undefined = $derived(
		this.path && this.app.diskfiles.get_by_path(this.path),
	);

	// The current relative path value for display in the XML path attribute
	readonly relative_path = $derived(this.diskfile?.path_relative);

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
			void this.app.diskfiles.update(this.path, value);
		}
	}

	constructor(options: Diskfile_Part_Options) {
		super(Diskfile_Part_Json, options);
		this.init();
	}

	// TODO @many this initialization is awkward, ideally becomes refactored to mostly derived
	/**
	 * Links this part to an editor state.
	 */
	link_editor_state(editor_state: {current_content: string} | null): void {
		this.#editor_state = editor_state;
	}
}

export const Diskfile_Part_Schema = z.instanceof(Diskfile_Part);
