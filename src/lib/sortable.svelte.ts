import type {Thunk} from '@ryanatkn/belt/function.js';
import type {Cell} from '$lib/cell.svelte.js';

export interface Sorter<T> {
	key: string;
	label: string;
	fn: (a: T, b: T) => number;
}

/**
 * Manages the sortable state for a collection of items with reactive data sources.
 */
export class Sortable<T> {
	/**
	 * Thunk to get the current items array reactively.
	 */
	#items_getter: Thunk<Array<T>>;
	readonly items: Array<T> = $derived.by(() => this.#items_getter());

	/**
	 * Thunk to get the current sorters reactively.
	 */
	#sorters_getter: Thunk<Array<Sorter<T>>>;
	readonly sorters: Array<Sorter<T>> = $derived.by(() => this.#sorters_getter());

	/**
	 * Optional thunk to get the current default sort key reactively.
	 */
	#key_getter_default: Thunk<string | undefined> | undefined;
	readonly default_key: string | undefined = $derived.by(() => this.#key_getter_default?.());

	/** Current active sort key */
	active_key: string = $state('');

	/**
	 * The currently active sorter.
	 */
	readonly active_sorter: Sorter<T> | undefined = $derived(
		this.sorters.find((s) => s.key === this.active_key),
	);

	/**
	 * The sort function from the active sorter.
	 */
	readonly active_sort_fn: ((a: T, b: T) => number) | undefined = $derived(this.active_sorter?.fn);

	/**
	 * Sorted items based on the current active sorter.
	 */
	readonly sorted_items: Array<T> = $derived.by(() => {
		const items = [...this.items];

		// Return unsorted if no sort function
		if (!this.active_sort_fn) return items;

		// Apply sorting
		return items.sort(this.active_sort_fn);
	});

	/**
	 * Create a new Sortable instance with reactive sources.
	 *
	 * @param items_getter Function that returns the current items array
	 * @param sorters_getter Function that returns the current sorters
	 * @param key_getter_default Optional function that returns the current default sort key
	 */
	constructor(
		items_getter: Thunk<Array<T>>,
		sorters_getter: Thunk<Array<Sorter<T>>>,
		key_getter_default?: Thunk<string | undefined>,
	) {
		this.#items_getter = items_getter;
		this.#sorters_getter = sorters_getter;
		this.#key_getter_default = key_getter_default;

		// Initialize active key from sorters or default
		this.update_active_key();
	}

	/**
	 * Updates the active key based on sorters and default key.
	 * Called automatically on initialization and when sorters change.
	 */
	update_active_key(): void {
		const sorters = this.sorters;
		const default_key = this.default_key;

		// Skip if no sorters
		if (!sorters.length) {
			this.active_key = '';
			return;
		}

		// If we have a default key and it exists in sorters, use it
		if (default_key && sorters.some((sorter) => sorter.key === default_key)) {
			this.active_key = default_key;
			return;
		}

		// If current key isn't valid anymore, reset to first sorter
		if (!sorters.some((sorter) => sorter.key === this.active_key)) {
			this.active_key = sorters[0].key;
		}
	}

	/**
	 * Set the active sorter by key.
	 * @returns true if successful, false if the key doesn't exist
	 */
	set_sort(key: string): boolean {
		if (this.sorters.some((sorter) => sorter.key === key)) {
			this.active_key = key;
			return true;
		}
		return false;
	}
}

// TODO @many these arent used in a typesafe way, asserting cell subtypes, maybe require the cell?
/**
 * Create a text sorter with optional direction.
 */
export const sort_by_text = <T extends Cell>(
	key: string,
	label: string,
	field: keyof T,
	direction: 'asc' | 'desc' = 'asc',
): Sorter<T> => {
	const multiplier = direction === 'desc' ? -1 : 1;
	return {
		key,
		label,
		fn: (a: T, b: T) => multiplier * String(a[field]).localeCompare(String(b[field])),
	};
};

// TODO @many these arent used in a typesafe way, asserting cell subtypes, maybe require the cell?
/**
 * Create a numeric sorter with optional direction.
 */
export const sort_by_numeric = <T extends Cell>(
	key: string,
	label: string,
	field: keyof T,
	direction: 'asc' | 'desc' = 'asc',
): Sorter<T> => {
	return {
		key,
		label,
		fn: (cell_a: T, cell_b: T) => {
			const a = cell_a[field];
			const b = cell_b[field];
			return direction === 'asc' ? (a < b ? -1 : a > b ? 1 : 0) : a > b ? -1 : a < b ? 1 : 0;
		},
	};
};
