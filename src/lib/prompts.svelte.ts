import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Prompt, Prompt_Json, Prompt_Schema} from '$lib/prompt.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_single_index, create_derived_index} from '$lib/indexed_collection_helpers.js';
import {to_reordered_list} from '$lib/list_helpers.js';
import type {Bit_Type} from './bit.svelte.js';

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
				result_schema: Prompt_Schema,
			}),

			create_derived_index({
				key: 'recent_prompts',
				compute: (collection) =>
					[...collection.by_id.values()].sort(
						(a, b) => new Date(b.created).getTime() - new Date(a.created).getTime(),
					),
				result_schema: z.array(Prompt_Schema),
				onadd: (items, item) => {
					// Insert at the right position based on creation date
					const index = items.findIndex(
						(p) => new Date(item.created).getTime() > new Date(p.created).getTime(),
					);
					if (index === -1) {
						items.push(item);
					} else {
						items.splice(index, 0, item);
					}
					return items;
				},
			}),

			create_derived_index({
				key: 'manual_order',
				compute: (collection) => Array.from(collection.by_id.values()),
				result_schema: z.array(Prompt_Schema),
			}),
		],
	});

	selected_id: Uuid | null = $state(null);
	readonly selected: Prompt | undefined = $derived(
		this.selected_id ? this.items.by_id.get(this.selected_id) : undefined,
	);

	/** Ordered array of prompts derived from the `manual_order` index. */
	readonly ordered_items: Array<Prompt> = $derived(this.items.derived_index('manual_order'));

	constructor(options: Prompts_Options) {
		super(Prompts_Json, options);

		this.decoders = {
			items: (items) => {
				if (Array.isArray(items)) {
					this.items.clear();
					for (const item_json of items) {
						this.add(item_json);
					}
				}
				return HANDLED;
			},
		};

		this.init();
	}

	/**
	 * Filter prompts that aren't in the given selected ids list.
	 * This is more efficient than keeping a derived index since the selection
	 * is dynamic based on the current chat.
	 */
	filter_unselected_prompts(selected_prompt_ids: Array<Uuid>): Array<Prompt> {
		// If no ids provided, return all prompts
		if (!selected_prompt_ids.length) {
			return this.ordered_items;
		}

		// Create a Set for O(1) lookups
		const selected_id_set = new Set(selected_prompt_ids);

		// Return prompts that aren't in the selected set
		return this.ordered_items.filter((prompt) => !selected_id_set.has(prompt.id));
	}

	filter_by_bit(bit: Bit_Type): Array<Prompt> {
		const {id} = bit;
		return this.ordered_items.filter((p) => p.bits.some((b) => b.id === id)); // TODO add an index?
	}

	// TODO BLOCK this is a weird API, the UI should be doing its sorting downstream not here
	add(json?: Prompt_Json): Prompt {
		const prompt = new Prompt({zzz: this.zzz, json});
		this.items.add(prompt);
		if (this.selected_id === null) {
			this.selected_id = prompt.id;
		}
		return prompt;
	}

	// TODO @many look into making these more generic, less manual bookkeeping
	add_many(prompts_json: Array<Prompt_Json>): Array<Prompt> {
		const prompts = prompts_json.map((json) => new Prompt({zzz: this.zzz, json}));

		this.items.add_many(prompts);

		// Set selected_id to the first prompt if none is selected
		if (this.selected_id === null && prompts.length > 0) {
			this.selected_id = prompts[0].id;
		}

		return prompts;
	}

	remove(prompt: Prompt): void {
		const removed = this.items.remove(prompt.id);
		if (removed && prompt.id === this.selected_id) {
			this.select_next();
		}
	}

	// TODO @many look into making these more generic, less manual bookkeeping
	remove_many(prompt_ids: Array<Uuid>): number {
		// Store the current selected id
		const current_selected = this.selected_id;

		// Remove the prompts
		const removed_count = this.items.remove_many(prompt_ids);

		// If the selected prompt was removed, select a new one
		if (current_selected !== null && prompt_ids.includes(current_selected)) {
			this.select_next();
		}

		return removed_count;
	}

	// TODO @many extract a selection helper class?
	select(prompt_id: Uuid | null): void {
		this.selected_id = prompt_id;
	}

	select_next(): void {
		const {by_id} = this.items;
		const next = by_id.values().next();
		this.select(next.value?.id ?? null);
	}

	reorder_prompts(from_index: number, to_index: number): void {
		this.items.indexes.manual_order = to_reordered_list(this.ordered_items, from_index, to_index);
	}

	remove_bit(bit_id: Uuid): void {
		if (!this.selected) return;
		this.selected.remove_bit(bit_id);
	}
}
