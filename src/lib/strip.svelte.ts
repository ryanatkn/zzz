import {z} from 'zod';
import {encode as tokenize} from 'gpt-tokenizer';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Datetime_Now, Uuid} from '$lib/zod_helpers.js';
import {Completion_Request, Completion_Response} from '$lib/action_types.js';
import {Cell_Json} from '$lib/cell_types.js';
import type {Bit_Type} from '$lib/bit.svelte.js';
import type {Zzz} from '$lib/zzz.svelte.js';

export const Strip_Role = z.enum(['user', 'assistant', 'system']);
export type Strip_Role = z.infer<typeof Strip_Role>;

export const Strip_Json = Cell_Json.extend({
	bit_id: Uuid,
	tape_id: Uuid.nullable().optional(),
	role: Strip_Role,
	request: Completion_Request.optional(),
	response: Completion_Response.optional(),
});
export type Strip_Json = z.infer<typeof Strip_Json>;

export const Strip_Schema = z.instanceof(Cell);

export interface Strip_Options extends Cell_Options<typeof Strip_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type
export class Strip extends Cell<typeof Strip_Json> {
	bit_id: Uuid = $state()!;
	tape_id: Uuid | null | undefined = $state();
	role: Strip_Role = $state()!;
	request?: Completion_Request = $state();
	response?: Completion_Response = $state();

	// Get the referenced bit - handle case where bit might not exist in registry
	readonly bit: Bit_Type | null = $derived(
		this.bit_id ? (this.zzz.bits.items.by_id.get(this.bit_id) ?? null) : null,
	);

	// Content always returns a string, normalizing null/undefined to empty string
	get content(): string {
		return this.bit?.content ?? '';
	}

	// Set content updates the bit's content if not null/undefined
	set content(value: string | null | undefined) {
		if (value != null && this.bit) {
			this.bit.content = value;
		}
	}

	// Derived properties based on normalized content
	readonly length: number = $derived(this.content.length);
	readonly tokens: Array<number> = $derived(tokenize(this.content));
	readonly token_count: number = $derived(this.tokens.length);

	readonly raw_content: string | null | undefined = $derived(this.bit?.content);
	readonly is_content_loaded: boolean = $derived(
		this.bit !== null && this.bit.content !== undefined,
	);
	readonly is_content_empty: boolean = $derived(
		this.bit === null || this.bit.content === null || this.bit.content === '',
	);
	readonly is_pending: boolean = $derived(
		this.role === 'assistant' && this.is_content_loaded && this.is_content_empty && !this.response,
	);

	constructor(options: Strip_Options) {
		super(Strip_Json, options);
		this.init();
	}

	/**
	 * Update the bit reference for this strip
	 */
	set_bit(bit: Bit_Type): void {
		this.bit_id = bit.id;
	}
}

/**
 * Create a strip with the provided content and role.
 * This creates a new bit to store the content.
 */
export const create_strip = (
	content: string,
	role: Strip_Role,
	options: Partial<Omit<Strip_Json, 'content' | 'role' | 'bit_id'>> = EMPTY_OBJECT,
	zzz: Zzz,
): Strip => {
	// Create a new bit for this content
	const bit = zzz.registry.instantiate('Text_Bit', {content});
	zzz.bits.add(bit);

	return zzz.registry.instantiate('Strip', {
		role,
		bit_id: bit.id,
		id: options.id || Uuid.parse(undefined),
		created: options.created || Datetime_Now.parse(undefined),
		tape_id: options.tape_id,
		request: options.request,
		response: options.response,
	});
};

/**
 * Create a strip that references an existing bit for its content
 */
export const create_strip_from_bit = (
	bit: Bit_Type,
	role: Strip_Role,
	options: Partial<Omit<Strip_Json, 'content' | 'role' | 'bit_id'>> = EMPTY_OBJECT,
): Strip => {
	return new Strip({
		zzz: bit.zzz,
		json: {
			role,
			bit_id: bit.id,
			id: options.id || Uuid.parse(undefined),
			created: options.created || Datetime_Now.parse(undefined),
			tape_id: options.tape_id,
			request: options.request,
			response: options.response,
		},
	});
};
