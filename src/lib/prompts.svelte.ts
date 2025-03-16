import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Prompt, Prompt_Json} from '$lib/prompt.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import type {Bit} from '$lib/bit.svelte.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_single_index, create_derived_index} from '$lib/indexed_collection_helpers.js';

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
	// Initialize items with proper typing and unified indexes
	readonly items: Indexed_Collection<Prompt> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'by_name',
				extractor: (prompt) => prompt.name,
				query_schema: z.string(),
			}),

			create_derived_index({
				key: 'recent_prompts',
				compute: (collection) => {
					// Sort by creation date (newest first)
					return [...collection.all].sort(
						(a, b) => new Date(b.created).getTime() - new Date(a.created).getTime(),
					);
				},
				on_add: (items, item) => {
					// Insert at the right position based on creation date
					const index = items.findIndex(
						(existing) => new Date(item.created).getTime() > new Date(existing.created).getTime(),
					);
					if (index === -1) {
						items.push(item);
					} else {
						items.splice(index, 0, item);
					}
					return items;
				},
			}),
		],
	});

	selected_id: Uuid | null = $state(null);
	selected: Prompt | undefined = $derived(
		this.selected_id ? this.items.by_id.get(this.selected_id) : undefined,
	);

	constructor(options: Prompts_Options) {
		super(Prompts_Json, options);

		this.decoders = {
			items: (items) => {
				if (Array.isArray(items)) {
					this.items.clear();
					for (const item_json of items) {
						this.add(false, item_json);
					}
				}
				return HANDLED;
			},
		};

		this.init();
	}

	/**
	 * Filter prompts that aren't in the given selected IDs list
	 * This is more efficient than keeping a derived index since the selection
	 * is dynamic based on the current chat
	 */
	filter_unselected_prompts(selected_prompt_ids: Array<Uuid>): Array<Prompt> {
		// If no IDs provided, return all prompts
		if (!selected_prompt_ids.length) {
			return this.items.all;
		}

		// Create a Set for O(1) lookups
		const selected_id_set = new Set(selected_prompt_ids);

		// Return prompts that aren't in the selected set
		return this.items.all.filter((prompt) => !selected_id_set.has(prompt.id));
	}

	// TODO BLOCK this is a weird API, the UI should be doing its sorting downstream not here
	add(first = true, json?: Prompt_Json): Prompt {
		const prompt = new Prompt({zzz: this.zzz, json});
		if (first) {
			this.items.add_first(prompt);
		} else {
			this.items.add(prompt);
		}
		if (this.selected_id === null) {
			this.selected_id = prompt.id;
		}
		return prompt;
	}

	add_many(prompts_json: Array<Prompt_Json>, first = false): Array<Prompt> {
		const prompts = prompts_json.map((json) => new Prompt({zzz: this.zzz, json}));

		if (first) {
			// Add each prompt to the beginning in reverse order to maintain original order
			for (let i = prompts.length - 1; i >= 0; i--) {
				this.items.add_first(prompts[i]);
			}
		} else {
			this.items.add_many(prompts);
		}

		// Set selected_id to the first prompt if none is selected
		if (this.selected_id === null && prompts.length > 0) {
			this.selected_id = prompts[0].id;
		}

		return prompts;
	}

	remove(prompt: Prompt): void {
		const removed = this.items.remove(prompt.id);
		if (removed && prompt.id === this.selected_id) {
			// Find next prompt to select
			const remaining_items = this.items.all;
			const next_prompt = remaining_items.length > 0 ? remaining_items[0] : undefined;
			this.selected_id = next_prompt ? next_prompt.id : null;
		}
	}

	remove_many(prompt_ids: Array<Uuid>): number {
		// Store the current selected ID
		const current_selected = this.selected_id;

		// Remove the prompts
		const removed_count = this.items.remove_many(prompt_ids);

		// If the selected prompt was removed, select a new one
		if (current_selected !== null && prompt_ids.includes(current_selected)) {
			const remaining_items = this.items.all;
			const next_prompt = remaining_items.length > 0 ? remaining_items[0] : undefined;
			this.selected_id = next_prompt ? next_prompt.id : null;
		}

		return removed_count;
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
