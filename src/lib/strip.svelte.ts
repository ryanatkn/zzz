import type {Omit_Strict} from '@ryanatkn/belt/types.js';

import {estimate_token_count} from '$lib/helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import type {Bit_Type} from '$lib/bit.svelte.js';
import type {Frontend} from '$lib/frontend.svelte.js';
import {Strip_Json, type Strip_Role} from '$lib/strip_types.js';
import type {Completion_Request, Completion_Response} from '$lib/completion_types.js';

// TODO rename? is more like a message, maybe `Tape_Message`, idk, maybe rethink "tape" too

export interface Strip_Options extends Cell_Options<typeof Strip_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Strip extends Cell<typeof Strip_Json> {
	bit_id: Uuid = $state()!;
	tape_id: Uuid | null | undefined = $state();
	role: Strip_Role = $state()!;
	request: Completion_Request | undefined = $state.raw();
	response: Completion_Response | undefined = $state.raw();

	// Get the referenced bit - handle case where bit might not exist in registry
	readonly bit: Bit_Type | null = $derived(this.app.bits.items.by_id.get(this.bit_id) ?? null);

	get enabled(): boolean {
		return this.bit?.enabled ?? false;
	}
	set enabled(value: boolean) {
		if (this.bit) {
			this.bit.enabled = value;
		}
	}

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
	readonly token_count: number = $derived(estimate_token_count(this.content));

	readonly raw_content: string | null | undefined = $derived(this.bit?.content);
	readonly is_content_loaded: boolean = $derived(
		this.bit !== null && this.bit.content !== undefined,
	);
	readonly is_content_empty: boolean = $derived(
		this.bit === null || this.bit.content === null || this.bit.content === '',
	);

	readonly pending: boolean = $derived(
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
 * Create a strip that references an existing bit for its content
 */
export const create_strip_from_bit = (
	bit: Bit_Type,
	role: Strip_Role,
	json: Partial<Omit_Strict<Strip_Json, 'role' | 'bit_id'>>,
): Strip => {
	return new Strip({
		app: bit.app,
		json: {
			...json,
			role,
			bit_id: bit.id,
		},
	});
};

/**
 * Create a strip with the provided content and role.
 * This creates a new bit to store the content.
 */
export const create_strip_from_text = (
	content: string,
	role: Strip_Role,
	json: Partial<Omit_Strict<Strip_Json, 'role' | 'bit_id'>>,
	app: Frontend,
): Strip => {
	const bit = app.bits.add({type: 'text', content});

	return new Strip({
		app,
		json: {
			...json,
			role,
			bit_id: bit.id,
		},
	});
};
