import {SvelteMap} from 'svelte/reactivity';

/**
 * Interface for objects that can be stored in an indexed collection
 */
export interface Indexed_Item {
	id: string;
}

/**
 * Type-safe configuration for additional indexes
 */
export interface Index_Config<T, K extends string, V> {
	key: K;
	extractor: (item: T) => V;
	multi?: boolean; // Whether this index maps to multiple items
}

/**
 * A helper class for managing collections that need efficient lookups
 * with automatic index maintenance
 */
export class Indexed_Collection<T extends Indexed_Item, K extends string = never> {
	// The main collection of items
	array: Array<T> = $state([]);

	// The primary index by ID is always available
	readonly by_id: SvelteMap<string, T> = new SvelteMap();

	// Additional single-value indexes (one key maps to one item)
	readonly single_indexes: Partial<Record<K, SvelteMap<any, T>>> = {};

	// Additional multi-value indexes (one key maps to many items)
	readonly multi_indexes: Partial<Record<K, SvelteMap<any, Array<T>>>> = {};

	#configs: Array<Index_Config<T, K, any>> = [];

	constructor(options?: {indexes?: Array<Index_Config<T, K, any>>; initial_items?: Array<T>}) {
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

	// TODO maybe make this a cell? could explicitly cleanup on destroy
	toJSON(): Array<any> {
		return $state.snapshot(this.array);
	}

	/**
	 * Add an item to the collection and update all indexes
	 */
	add(item: T): T {
		this.array.push(item);
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
		this.array.unshift(item);
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
	 * Remove an item from the collection and update all indexes
	 */
	remove(item: T): boolean {
		// Find the item by ID rather than by reference
		const stored_item = this.by_id.get(item.id);
		if (!stored_item) return false;

		// Find the index of the item in the array
		const index = this.array.findIndex((i) => i.id === item.id);
		if (index !== -1) {
			this.array.splice(index, 1);
			this.by_id.delete(item.id);

			// Update all additional indexes
			for (const config of this.#configs) {
				const key = config.extractor(item);
				if (key !== undefined && key !== null) {
					if (config.multi) {
						const collection = this.multi_indexes[config.key]!.get(key);
						if (collection) {
							const updated = collection.filter((i) => i.id !== item.id);
							if (updated.length === 0) {
								this.multi_indexes[config.key]!.delete(key);
							} else {
								this.multi_indexes[config.key]!.set(key, updated);
							}
						}
					} else {
						// Only delete if this exact key is mapped to this exact item
						const mapped_item = this.single_indexes[config.key]!.get(key);
						if (mapped_item && mapped_item.id === item.id) {
							this.single_indexes[config.key]!.delete(key);
						}
					}
				}
			}

			return true;
		}
		return false;
	}

	/**
	 * Remove an item by its ID
	 */
	remove_by_id(id: string): boolean {
		const item = this.by_id.get(id);
		if (item) {
			return this.remove(item);
		}
		return false;
	}

	/**
	 * Get an item by its ID
	 */
	get(id: string): T | undefined {
		return this.by_id.get(id);
	}

	/**
	 * Check if the collection has an item with the given ID
	 */
	has(id: string): boolean {
		return this.by_id.has(id);
	}

	/**
	 * Reorder items in the collection
	 */
	reorder(from_index: number, to_index: number): void {
		if (from_index === to_index) return;
		if (from_index < 0 || to_index < 0) return;
		if (from_index >= this.array.length || to_index >= this.array.length) return;

		// Perform the reorder
		const [item] = this.array.splice(from_index, 1);
		this.array.splice(to_index, 0, item);
	}

	/**
	 * Get the current count of items
	 */
	get size(): number {
		return this.array.length;
	}

	/**
	 * Clear all items and reset indexes
	 */
	clear(): void {
		this.array.length = 0;
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
