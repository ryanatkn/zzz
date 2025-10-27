import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Thread} from '$lib/thread.svelte.js';
import {Thread_Json, type Thread_Json_Input} from '$lib/thread_types.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_multi_index, create_derived_index} from '$lib/indexed_collection_helpers.svelte.js';
import {Model_Name} from '$lib/model.svelte.js';
import {to_reordered_list} from '$lib/list_helpers.js';
import {Cell_Json} from '$lib/cell_types.js';

export const Threads_Json = Cell_Json.extend({
	items: z.array(Thread_Json).default(() => []),
	selected_id: z.string().nullable().default(null),
}).meta({cell_class_name: 'Threads'});
export type Threads_Json = z.infer<typeof Threads_Json>;
export type Threads_Json_Input = z.input<typeof Threads_Json>;

export interface Threads_Options extends Cell_Options<typeof Threads_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Threads extends Cell<typeof Threads_Json> {
	readonly items: Indexed_Collection<Thread> = new Indexed_Collection({
		indexes: [
			create_multi_index({
				key: 'by_model_name',
				extractor: (thread) => thread.model_name,
				query_schema: Model_Name,
			}),
			create_derived_index({
				key: 'manual_order',
				compute: (collection) => collection.values,
			}),
		],
	});

	selected_id: Uuid | null = $state(null);
	readonly selected: Thread | undefined = $derived(
		this.selected_id ? this.items.by_id.get(this.selected_id) : undefined,
	);
	readonly selected_id_error: boolean = $derived(
		this.selected_id !== null && this.selected === undefined,
	);

	/** Ordered array of threads derived from the `manual_order` index. */
	readonly ordered_items: Array<Thread> = $derived(this.items.derived_index('manual_order'));

	constructor(options: Threads_Options) {
		super(Threads_Json, options);

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

		// Initialize explicitly after all properties are defined
		this.init();
	}

	add(json?: Thread_Json_Input, select?: boolean): Thread {
		const thread = new Thread({app: this.app, json});
		return this.add_thread(thread, select);
	}

	// Consistent method signature with other collection classes
	add_thread(thread: Thread, select?: boolean): Thread {
		this.items.add(thread);

		if (select || this.selected_id === null) {
			this.selected_id = thread.id;
		}
		return thread;
	}

	add_many(threads_json: Array<Thread_Json_Input>, select?: boolean | number): Array<Thread> {
		const threads = threads_json.map((json) => new Thread({app: this.app, json}));
		this.items.add_many(threads);

		// Select the first or the specified thread if none is currently selected
		if (
			select === true ||
			typeof select === 'number' ||
			(this.selected_id === null && threads.length > 0)
		) {
			this.selected_id = threads[typeof select === 'number' ? select : 0].id;
		}

		return threads;
	}

	remove(id: Uuid): void {
		// For a single id, use a direct approach rather than creating an array
		this.#remove_reference_from_chats(id);

		const removed = this.items.remove(id);
		if (removed && id === this.selected_id) {
			this.select_next();
		}
	}

	remove_many(ids: Array<Uuid>): number {
		// Remove references to these threads from all chats before removing them
		this.#remove_references_from_chats(ids);

		// Store the current selected id
		const current_selected = this.selected_id;

		// Remove the threads
		const removed_count = this.items.remove_many(ids);

		// If the selected thread was removed, select a new one
		if (current_selected !== null && ids.includes(current_selected)) {
			this.select_next();
		}

		return removed_count;
	}

	// TODO these two methods feel like a code smell, should maintain the collections more automatically
	#remove_reference_from_chats(thread_id: Uuid): void {
		for (const chat of this.app.chats.items.by_id.values()) {
			chat.remove_thread(thread_id);
		}
	}
	#remove_references_from_chats(thread_ids: Array<Uuid>): void {
		// If there's only one item, use the single-item optimized version
		if (thread_ids.length === 1) {
			this.#remove_reference_from_chats(thread_ids[0]!); // guaranteed by length === 1
			return;
		}

		for (const chat of this.app.chats.items.by_id.values()) {
			chat.remove_threads(thread_ids);
		}
	}

	// TODO @many extract a selection helper class?
	select(thread_id: Uuid | null): void {
		this.selected_id = thread_id;
	}

	select_next(): void {
		const {by_id} = this.items;
		const next = by_id.values().next();
		this.select(next.value?.id ?? null);
	}

	reorder_threads(from_index: number, to_index: number): void {
		this.items.indexes.manual_order = to_reordered_list(this.ordered_items, from_index, to_index);
	}
}
