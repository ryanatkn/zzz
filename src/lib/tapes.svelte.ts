import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Tape} from '$lib/tape.svelte.js';
import {Tape_Json} from '$lib/tape_types.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_multi_index, create_derived_index} from '$lib/indexed_collection_helpers.js';
import {Model_Name} from '$lib/model.svelte.js';
import {to_reordered_list} from '$lib/list_helpers.js';

export const Tapes_Json = z
	.object({
		items: cell_array(
			z.array(Tape_Json).default(() => []),
			'Tape',
		),
		selected_id: z.string().nullable().default(null),
	})
	.default(() => ({
		items: [],
		selected_id: null,
	}));

export type Tapes_Json = z.infer<typeof Tapes_Json>;

export interface Tapes_Options extends Cell_Options<typeof Tapes_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Tapes extends Cell<typeof Tapes_Json> {
	readonly items: Indexed_Collection<Tape> = new Indexed_Collection({
		indexes: [
			create_multi_index({
				key: 'by_model_name',
				extractor: (tape) => tape.model_name,
				query_schema: Model_Name,
				result_schema: z.instanceof(Tape),
			}),
			create_derived_index({
				key: 'manual_order',
				compute: (collection) => Array.from(collection.by_id.values()),
				result_schema: z.array(z.instanceof(Tape)),
			}),
		],
	});

	selected_id: Uuid | null = $state(null);
	readonly selected: Tape | undefined = $derived(
		this.selected_id ? this.items.by_id.get(this.selected_id) : undefined,
	);
	readonly selected_id_error: boolean = $derived(
		this.selected_id !== null && this.selected === undefined,
	);

	/** Ordered array of tapes derived from the `manual_order` index. */
	readonly ordered_items: Array<Tape> = $derived(this.items.derived_index('manual_order'));

	constructor(options: Tapes_Options) {
		super(Tapes_Json, options);

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

		// Initialize explicitly after all properties are defined
		this.init();
	}

	add(json?: z.input<typeof Tape_Json>, select?: boolean): Tape {
		const tape = new Tape({zzz: this.zzz, json});
		return this.add_tape(tape, select);
	}

	// Consistent method signature with other collection classes
	add_tape(tape: Tape, select?: boolean): Tape {
		this.items.add(tape);

		if (select || this.selected_id === null) {
			this.selected_id = tape.id;
		}
		return tape;
	}

	add_many(tapes_json: Array<z.input<typeof Tape_Json>>, select?: boolean | number): Array<Tape> {
		const tapes = tapes_json.map((json) => new Tape({zzz: this.zzz, json}));

		// Add all tapes to the collection
		for (const tape of tapes) {
			this.items.add(tape);
		}

		// Select the first or the specified tape if none is currently selected
		if (
			select === true ||
			typeof select === 'number' ||
			(this.selected_id === null && tapes.length > 0)
		) {
			this.selected_id = tapes[typeof select === 'number' ? select : 0].id;
		}

		return tapes;
	}

	remove(id: Uuid): void {
		// For a single ID, use a direct approach rather than creating an array
		this.#remove_reference_from_chats(id);

		const removed = this.items.remove(id);
		if (removed && id === this.selected_id) {
			this.select_next();
		}
	}

	remove_many(ids: Array<Uuid>): number {
		// Remove references to these tapes from all chats before removing them
		this.#remove_references_from_chats(ids);

		// Store the current selected id
		const current_selected = this.selected_id;

		// Remove the tapes
		const removed_count = this.items.remove_many(ids);

		// If the selected tape was removed, select a new one
		if (current_selected !== null && ids.includes(current_selected)) {
			this.select_next();
		}

		return removed_count;
	}

	// TODO these two methods feel like a code smell, should maintain the collections more automatically
	#remove_reference_from_chats(tape_id: Uuid): void {
		for (const chat of this.zzz.chats.items.by_id.values()) {
			chat.remove_tape(tape_id);
		}
	}
	#remove_references_from_chats(tape_ids: Array<Uuid>): void {
		// If there's only one item, use the single-item optimized version
		if (tape_ids.length === 1) {
			this.#remove_reference_from_chats(tape_ids[0]);
			return;
		}

		for (const chat of this.zzz.chats.items.by_id.values()) {
			chat.remove_tapes(tape_ids);
		}
	}

	// TODO @many extract a selection helper class?
	select(tape_id: Uuid | null): void {
		this.selected_id = tape_id;
	}

	select_next(): void {
		const {by_id} = this.items;
		const next = by_id.values().next();
		this.select(next.value?.id ?? null);
	}

	reorder_tapes(from_index: number, to_index: number): void {
		this.items.indexes.manual_order = to_reordered_list(this.ordered_items, from_index, to_index);
	}
}
