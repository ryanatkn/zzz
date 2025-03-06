import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Prompt, Prompt_Json} from '$lib/prompt.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import type {Bit} from '$lib/bit.svelte.js';
import {reorder_list} from '$lib/list_helpers.js';
import {cell_array} from '$lib/cell_helpers.js';

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

export interface Prompts_Options extends Cell_Options<typeof Prompts_Json> {}

export class Prompts extends Cell<typeof Prompts_Json> {
	items: Array<Prompt> = $state([]);
	selected_id: Uuid | null = $state(null);

	selected: Prompt | undefined = $derived(this.items.find((p) => p.id === this.selected_id));

	constructor(options: Prompts_Options) {
		super(Prompts_Json, options);
		this.init();
	}

	add(): Prompt {
		const prompt = new Prompt({zzz: this.zzz});
		this.items.unshift(prompt); // TODO BLOCK @many use push and render with sort+filter
		if (this.selected_id === null) {
			this.selected_id = prompt.id;
		}
		return prompt;
	}

	remove(prompt: Prompt): void {
		const index = this.items.indexOf(prompt);
		if (index !== -1) {
			const removed = this.items.splice(index, 1);
			if (removed[0].id === this.selected_id) {
				const next_prompt = this.items[index === 0 ? 0 : index - 1] as Prompt | undefined;
				if (next_prompt) {
					this.select(next_prompt.id);
				} else {
					this.selected_id = null;
				}
			}
		}
	}

	select(prompt_id: Uuid | null): void {
		this.selected_id = prompt_id;
	}

	reorder_prompts(from_index: number, to_index: number): void {
		reorder_list(this.items, from_index, to_index);
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
