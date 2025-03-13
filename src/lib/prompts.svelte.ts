import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Prompt, Prompt_Json} from '$lib/prompt.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import type {Bit} from '$lib/bit.svelte.js';
import {cell_array} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';

export const Prompts_Json = z
	.object({
		items: cell_array(
			z.array(Prompt_Json).default(() => []),
			'Prompt',
		),
		selected_id: z.string().nullable().default(null),
	})
	.default(() => ({
		items: [],
		selected_id: null,
	}));

export type Prompts_Json = z.infer<typeof Prompts_Json>;

export interface Prompts_Options extends Cell_Options<typeof Prompts_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type
export class Prompts extends Cell<typeof Prompts_Json> {
	// Initialize items directly at property declaration site
	readonly items: Indexed_Collection<Prompt> = new Indexed_Collection();

	selected_id: Uuid | null = $state(null);
	selected: Prompt | undefined = $derived(
		this.selected_id ? this.items.by_id.get(this.selected_id) : undefined,
	);

	constructor(options: Prompts_Options) {
		super(Prompts_Json, options);
		this.init();
	}

	add(): Prompt {
		const prompt = new Prompt({zzz: this.zzz});
		this.items.add_first(prompt);
		if (this.selected_id === null) {
			this.selected_id = prompt.id;
		}
		return prompt;
	}

	remove(prompt: Prompt): void {
		const removed = this.items.remove(prompt);
		if (removed && prompt.id === this.selected_id) {
			// Find next prompt to select
			const remaining_items = this.items.array;
			const next_prompt = remaining_items.length > 0 ? remaining_items[0] : undefined;
			this.selected_id = next_prompt ? next_prompt.id : null;
		}
	}

	select(prompt_id: Uuid | null): void {
		this.selected_id = prompt_id;
	}

	reorder_prompts(from_index: number, to_index: number): void {
		this.items.reorder(from_index, to_index);
	}

	add_bit(): void {
		if (!this.selected) return;
		this.selected.add_bit();
	}

	update_bit(bit_id: Uuid, updates: Partial<Omit<Bit, 'id'>>): void {
		if (!this.selected) return;
		this.selected.update_bit(bit_id, updates);
	}

	remove_bit(bit_id: Uuid): void {
		if (!this.selected) return;
		this.selected.remove_bit(bit_id);
	}
}
