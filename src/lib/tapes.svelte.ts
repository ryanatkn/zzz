import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Tape} from '$lib/tape.svelte.js';
import {Tape_Json} from '$lib/tape_types.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_multi_index} from '$lib/indexed_collection_helpers.js';
import {Model_Name} from '$lib/model.svelte.js';

export type Tape_Single_Indexes = never;
export type Tape_Multi_Indexes = 'by_model_name';

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
		],
	});

	selected_id: Uuid | null = $state(null);
	selected: Tape | undefined = $derived(
		this.selected_id ? this.items.by_id.get(this.selected_id) : undefined,
	);
	selected_id_error: boolean = $derived(this.selected_id !== null && this.selected === undefined);

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

	add(json?: z.input<typeof Tape_Json>, first = true, select?: boolean): Tape {
		const tape = new Tape({zzz: this.zzz, json});
		return this.add_tape(tape, first, select);
	}

	// Consistent method signature with other collection classes
	add_tape(tape: Tape, first = true, select?: boolean): Tape {
		if (first) {
			this.items.add_first(tape);
		} else {
			this.items.add(tape);
		}
		if (select || this.selected_id === null) {
			this.selected_id = tape.id;
		}
		return tape;
	}

	add_many(
		tapes_json: Array<z.input<typeof Tape_Json>>,
		first = true,
		select?: boolean | number,
	): Array<Tape> {
		const tapes = tapes_json.map((json) => new Tape({zzz: this.zzz, json}));

		// Add all tapes to the collection - we can simplify this loop
		for (const tape of first ? tapes.toReversed() : tapes) {
			this.items.add_first(first ? tape : tape);
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
			this.#select_next_available_tape();
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
			this.#select_next_available_tape();
		}

		return removed_count;
	}

	/**
	 * Selects the next available tape, if any exist.
	 */
	#select_next_available_tape(): void {
		const remaining_items = this.items.all;
		const next_tape = remaining_items.length > 0 ? remaining_items[0] : undefined;
		this.selected_id = next_tape ? next_tape.id : null;
	}

	// TODO these two methods feel like a code smell, should maintain the collections more automatically
	#remove_reference_from_chats(tape_id: Uuid): void {
		for (const chat of this.zzz.chats.items.all) {
			chat.remove_tape(tape_id);
		}
	}
	#remove_references_from_chats(tape_ids: Array<Uuid>): void {
		// If there's only one item, use the single-item optimized version
		if (tape_ids.length === 1) {
			this.#remove_reference_from_chats(tape_ids[0]);
			return;
		}

		for (const chat of this.zzz.chats.items.all) {
			chat.remove_tapes(tape_ids);
		}
	}

	select(tape_id: Uuid | null): void {
		this.selected_id = tape_id;
	}

	reorder_tapes(from_index: number, to_index: number): void {
		this.items.reorder(from_index, to_index);
	}
}
