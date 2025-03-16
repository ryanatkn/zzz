import {SvelteMap} from 'svelte/reactivity';
import {Uuid} from '$lib/zod_helpers.js'; // added import

/**
 * Interface for objects that can be stored in an indexed collection
 */
export interface Indexed_Item {
	id: Uuid; // updated to use Uuid instead of string
}

/**
 * Type-safe configuration for additional indexes
 */
export interface Index_Config<T, K extends string, V> {
	key: K;
	extractor: (item: T) => V;
	multi?: boolean; // Whether this index maps to multiple items
}

export interface Indexed_Collection_Options<T extends Indexed_Item, K extends string> {
	indexes?: Array<Index_Config<T, K, any>>;
	initial_items?: Array<T>;
}

/**
 * A helper class for managing collections that need efficient lookups
 * with automatic index maintenance
 */
export class Indexed_Collection<T extends Indexed_Item, K extends string = never> {
	// The main collection of items
	all: Array<T> = $state([]);

	// The primary index by ID now keyed by Uuid instead of string
	readonly by_id: SvelteMap<Uuid, T> = new SvelteMap();

	// Additional single-value indexes (one key maps to one item)
	readonly single_indexes: Partial<Record<K, SvelteMap<any, T>>> = {};

	// Additional multi-value indexes (one key maps to many items)
	readonly multi_indexes: Partial<Record<K, SvelteMap<any, Array<T>>>> = {};

	#configs: Array<Index_Config<T, K, any>> = [];

	constructor(options?: Indexed_Collection_Options<T, K>) {
		// Set up additional indexes
		if (options?.indexes) {
			this.#configs = options.indexes;

			// Initialize the index maps
			for (const config of this.#configs) {
				if (config.multi) {
					this.multi_indexes[config.key] = new SvelteMap();
				} else {
					this.single_indexes[config.key] = new SvelteMap();
				}
			}
		}

		// Add any initial items
		if (options?.initial_items) {
			for (const item of options.initial_items) {
				this.add(item);
			}
		}
	}

	toJSON(): Array<any> {
		return $state.snapshot(this.all);
	}

	/**
	 * Add an item to the collection and update all indexes
	 */
	add(item: T): T {
		this.all.push(item);
		this.by_id.set(item.id, item);

		// Update all additional indexes
		for (const config of this.#configs) {
			const key = config.extractor(item);
			if (key !== undefined && key !== null) {
				if (config.multi) {
					const collection = this.multi_indexes[config.key]!.get(key) || [];
					collection.push(item);
					this.multi_indexes[config.key]!.set(key, collection);
				} else {
					this.single_indexes[config.key]!.set(key, item);
				}
			}
		}

		return item;
	}

	/**
	 * Add an item to the beginning of the collection
	 */
	add_first(item: T): T {
		this.all.unshift(item);
		this.by_id.set(item.id, item);

		// Update all additional indexes
		for (const config of this.#configs) {
			const key = config.extractor(item);
			if (key !== undefined && key !== null) {
				if (config.multi) {
					const collection = this.multi_indexes[config.key]!.get(key) || [];
					collection.unshift(item);
					this.multi_indexes[config.key]!.set(key, collection);
				} else {
					this.single_indexes[config.key]!.set(key, item);
				}
			}
		}

		return item;
	}

	/**
	 * Remove an item by its ID and update all indexes
	 */
	remove(id: Uuid): boolean {
		const item = this.by_id.get(id);
		if (!item) return false;

		// Find the index of the item in the array
		const index = this.all.findIndex((i) => i.id === id); // TODO consider using a map for index lookup
		if (index !== -1) {
			this.all.splice(index, 1);
			this.by_id.delete(id);

			// Update all additional indexes
			for (const config of this.#configs) {
				const key = config.extractor(item);
				if (key !== undefined && key !== null) {
					if (config.multi) {
						const multi_index = this.multi_indexes[config.key]!;
						const collection = multi_index.get(key);

						if (collection) {
							// Filter out the removed item
							const updated = collection.filter((i) => i.id !== id);

							// If no items left with this key, remove the key from the index
							if (updated.length === 0) {
								multi_index.delete(key);
							} else {
								multi_index.set(key, updated);
							}
						}
					} else {
						// For single-value indexes, only remove if this item is mapped to this key
						const single_index = this.single_indexes[config.key]!;
						const mapped_item = single_index.get(key);

						if (mapped_item && mapped_item.id === id) {
							single_index.delete(key);
						}
					}
				}
			}

			return true;
		}
		return false;
	}

	/**
	 * Get an item by its ID
	 */
	get(id: Uuid): T | undefined {
		return this.by_id.get(id);
	}

	/**
	 * Check if the collection has an item with the given ID
	 */
	has(id: Uuid): boolean {
		return this.by_id.has(id);
	}

	/**
	 * Reorder items in the collection
	 */
	reorder(from_index: number, to_index: number): void {
		if (from_index === to_index) return;
		if (from_index < 0 || to_index < 0) return;
		if (from_index >= this.all.length || to_index >= this.all.length) return;

		// Perform the reorder
		const [item] = this.all.splice(from_index, 1);
		this.all.splice(to_index, 0, item);
	}

	/**
	 * Get the current count of items
	 */
	get size(): number {
		return this.all.length;
	}

	/**
	 * Clear all items and reset indexes
	 */
	clear(): void {
		this.all.length = 0;
		this.by_id.clear();

		// Clear all additional indexes
		for (const config of this.#configs) {
			if (config.multi) {
				this.multi_indexes[config.key]!.clear();
			} else {
				this.single_indexes[config.key]!.clear();
			}
		}
	}
}
