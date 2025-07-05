import {z} from 'zod';
import {page} from '$app/state';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Prompt, Prompt_Json, Prompt_Schema, type Prompt_Json_Input} from '$lib/prompt.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_single_index, create_derived_index} from '$lib/indexed_collection_helpers.svelte.js';
import {to_reordered_list} from '$lib/list_helpers.js';
import type {Bit_Type} from '$lib/bit.svelte.js';
import {get_unique_name} from '$lib/helpers.js';
import {to_prompts_url} from '$lib/nav_helpers.js';
import {Cell_Json} from '$lib/cell_types.js';
import {goto_unless_current} from '$lib/navigation_helpers.js';

export const Prompts_Json = Cell_Json.extend({
	items: cell_array(
		z.array(Prompt_Json).default(() => []),
		'Prompt',
	),
	selected_id: z.string().nullable().default(null),
	show_sort_controls: z.boolean().default(false),
});
export type Prompts_Json = z.infer<typeof Prompts_Json>;
export type Prompts_Json_Input = z.input<typeof Prompts_Json>;

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
					collection.values
						.slice()
						.sort((a, b) => new Date(b.created).getTime() - new Date(a.created).getTime()),
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
				compute: (collection) => collection.values,
				result_schema: z.array(Prompt_Schema),
			}),
		],
	});

	#selected_id: Uuid | null = $state()!;
	selected_id_last_non_null: Uuid | null = $state()!;
	get selected_id(): Uuid | null {
		return this.#selected_id;
	}
	set selected_id(value: Uuid | null) {
		this.#selected_id = value;
		if (value !== null) this.selected_id_last_non_null = value;
	}

	readonly selected: Prompt | undefined = $derived(
		this.selected_id ? this.items.by_id.get(this.selected_id) : undefined,
	);

	/** Controls visibility of sort controls in the prompts list. */
	show_sort_controls: boolean = $state(false);

	/** Ordered array of prompts derived from the `manual_order` index. */
	readonly ordered_items: Array<Prompt> = $derived(this.items.derived_index('manual_order'));

	constructor(options: Prompts_Options) {
		super(Prompts_Json, options);

		this.decoders = {
			// TODO @many improve this API, maybe infer or create a helper, duplicated many places
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

	filter_by_bit(bit: Bit_Type): Array<Prompt> {
		const {id} = bit;
		return this.ordered_items.filter((p) => p.bits.some((b) => b.id === id)); // TODO add an index?
	}

	add(json?: Prompt_Json_Input): Prompt {
		const j = !json?.name ? {...json, name: this.generate_unique_name('new prompt')} : json;
		const prompt = new Prompt({app: this.app, json: j});
		this.items.add(prompt);
		if (this.selected_id === null) {
			this.selected_id = prompt.id;
		}
		return prompt;
	}

	generate_unique_name(base_name: string = 'new prompt'): string {
		return get_unique_name(base_name, this.items.single_index('by_name'));
	}

	// TODO @many look into making these more generic, less manual bookkeeping
	add_many(prompts_json: Array<Prompt_Json_Input>): Array<Prompt> {
		const prompts = prompts_json.map((json) => new Prompt({app: this.app, json}));
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
			void this.select_next();
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
			void this.select_next();
		}

		return removed_count;
	}

	// TODO @many extract a selection helper class?
	select(prompt_id: Uuid | null): Promise<void> {
		return this.navigate_to(prompt_id);
	}

	select_next(): Promise<void> {
		const {by_id} = this.items;
		const next = by_id.values().next();
		return this.navigate_to(next.value?.id ?? null);
	}

	async navigate_to(prompt_id: Uuid | null, force = false): Promise<void> {
		const url = to_prompts_url(prompt_id);
		if (!force && page.url.pathname === url) return;
		return goto_unless_current(url);
	}

	reorder_prompts(from_index: number, to_index: number): void {
		this.items.indexes.manual_order = to_reordered_list(this.ordered_items, from_index, to_index);
	}

	remove_bit(bit_id: Uuid): void {
		if (!this.selected) return;
		this.selected.remove_bit(bit_id);
	}

	/**
	 * Toggles the visibility of sort controls in the prompts list.
	 */
	toggle_sort_controls(value = !this.show_sort_controls): void {
		this.show_sort_controls = value;
	}
}

export const Prompts_Schema = z.instanceof(Prompts);
