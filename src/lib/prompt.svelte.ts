import {z} from 'zod';

import {Uuid} from '$lib/zod_helpers.js';
import {to_preview, estimate_token_count} from '$lib/helpers.js';
import {Bit_Json, type Bit_Type} from '$lib/bit.svelte.js';
import {reorder_list} from '$lib/list_helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {format_prompt_content} from '$lib/prompt_helpers.js';

export interface Prompt_Message {
	role: 'user' | 'system';
	content: Array<Prompt_Action_Content>;
}

export type Prompt_Action_Content = string; // TODO ?

export const Prompt_Json = Cell_Json.extend({
	name: z.string().default(''),
	bits: z.array(Bit_Json).default(() => []),
});
export type Prompt_Json = z.infer<typeof Prompt_Json>;
export type Prompt_Json_Input = z.input<typeof Prompt_Json>;

export interface Prompt_Options extends Cell_Options<typeof Prompt_Json> {
	name?: string;
}

export class Prompt extends Cell<typeof Prompt_Json> {
	name: string = $state()!;
	bits: Array<Bit_Type> = $state()!;

	readonly content: string = $derived(format_prompt_content(this.bits));

	readonly length: number = $derived(this.content.length);
	readonly token_count: number = $derived(estimate_token_count(this.content));
	readonly content_preview: string = $derived(to_preview(this.content));

	constructor(options: Prompt_Options) {
		super(Prompt_Json, options);
		this.init();
	}

	/**
	 * Add a bit to this prompt.
	 */
	add_bit(bit: Bit_Type): Bit_Type {
		this.bits.push(bit);
		return bit;
	}

	remove_bit(id: Uuid): boolean {
		const index = this.bits.findIndex((f) => f.id === id);
		if (index !== -1) {
			this.bits.splice(index, 1);
			return true;
		}
		return false;
	}

	remove_all_bits(): void {
		this.bits = [];
	}

	reorder_bits(from_index: number, to_index: number): void {
		reorder_list(this.bits, from_index, to_index);
	}
}

export const Prompt_Schema = z.instanceof(Prompt);
