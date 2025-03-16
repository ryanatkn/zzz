import {SvelteMap} from 'svelte/reactivity';
import {Uuid} from '$lib/zod_helpers.js';

/**
 * Interface for objects that can be stored in an indexed collection
 */
export interface Indexed_Item {
	id: Uuid;
}

/**
 * The type of index with different behaviors
 */
export enum Index_Type {
	/** Maps a single property value to a single item */
	SINGLE = 'single',
	/** Maps a property value to multiple items */
	MULTI = 'multi',
	/** A derived collection that's updated incrementally */
	DERIVED = 'derived',
}

/**
 * Base configuration for all index types
 */
interface Index_Config_Base<K extends string> {
	key: K;
	type: Index_Type;
}

/**
 * Type-safe configuration for single-value indexes
 */
export interface Single_Index_Config<T, K extends string> extends Index_Config_Base<K> {
	type: Index_Type.SINGLE;
	extractor: (item: T) => any;
}

/**
 * Type-safe configuration for multi-value indexes
 */
export interface Multi_Index_Config<T, K extends string> extends Index_Config_Base<K> {
	type: Index_Type.MULTI;
	extractor: (item: T) => any;
}

/**
 * Configuration for derived collection indexes with incremental updates
 */
export interface Derived_Index_Config<T extends Indexed_Item, K extends string>
	extends Index_Config_Base<K> {
	type: Index_Type.DERIVED;
	/** Function that computes the initial collection */
	compute: (collection: Indexed_Collection<T>) => Array<T>;
	/** Optional function to update the collection when items are added */
	on_add?: (collection: Array<T>, new_item: T, source: Indexed_Collection<T>) => void;
	/** Optional function to update the collection when items are removed */
	on_remove?: (collection: Array<T>, removed_item: T, source: Indexed_Collection<T>) => void;
	/** Optional function to determine if an item matches this index (for efficient filtering) */
	matches?: (item: T) => boolean;
}

// Union type of all index configurations
export type Index_Config<T extends Indexed_Item> =
	| Single_Index_Config<T, string>
	| Multi_Index_Config<T, string>
	| Derived_Index_Config<T, string>;

export interface Indexed_Collection_Options<T extends Indexed_Item> {
	indexes?: Array<Index_Config<T>>;
	initial_items?: Array<T>;
}

/**
 * A helper class for managing collections that need efficient lookups
 * with automatic index maintenance
 */
export class Indexed_Collection<T extends Indexed_Item> {
	// The main collection of items
	all: Array<T> = $state([]);

	// The primary index by ID keyed by Uuid
	readonly by_id: SvelteMap<Uuid, T> = new SvelteMap();

	// Single-value indexes (one key maps to one item)
	readonly single_indexes: Record<string, SvelteMap<any, T>> = {};

	// Multi-value indexes (one key maps to many items)
	readonly multi_indexes: Record<string, SvelteMap<any, Array<T>>> = {};

	// Derived collections that are incrementally maintained
	readonly derived_indexes: Record<string, Array<T>> = {};

	// Store all index configs for reference
	#index_configs: Array<Index_Config<T>> = [];

	constructor(options?: Indexed_Collection_Options<T>) {
		// Set up indexes based on provided configurations
		if (options?.indexes) {
			this.#index_configs = options.indexes;

			// Initialize each index based on its type
			for (const config of this.#index_configs) {
				switch (config.type) {
					case Index_Type.SINGLE:
						this.single_indexes[config.key] = new SvelteMap();
						break;
					case Index_Type.MULTI:
						this.multi_indexes[config.key] = new SvelteMap();
						break;
					case Index_Type.DERIVED:
						// Start with empty array, will be populated after items are added
						this.derived_indexes[config.key] = [];
						break;
				}
			}
		}

		// Add any initial items
		if (options?.initial_items) {
			this.add_many(options.initial_items);

			// Initialize derived indexes now that we have items
			this.#initialize_derived_indexes();
		}
	}

	/**
	 * Initialize all derived indexes from scratch
	 */
	#initialize_derived_indexes(): void {
		// Find all derived index configs
		const derived_configs = this.#index_configs.filter(
			(config): config is Derived_Index_Config<T, string> => config.type === Index_Type.DERIVED,
		);

		// Compute each derived index
		for (const config of derived_configs) {
			// Make sure we're creating a fresh array - the compute function
			// must be responsible for proper filtering
			this.derived_indexes[config.key] = config.compute(this);
		}
	}

	toJSON(): Array<any> {
		return $state.snapshot(this.all);
	}

	/**
	 * Add multiple items to the collection at once with improved performance
	 */
	add_many(items: Array<T>): Array<T> {
		if (!items.length) return [];

		// Add all items to main array
		this.all.push(...items);

		// Batch update indexes
		for (const item of items) {
			// Update primary ID index
			this.by_id.set(item.id, item);

			// Update all other indexes
			this.#update_indexes_for_added_item(item);
		}

		return items;
	}

	/**
	 * Update all indexes when an item is added
	 */
	#update_indexes_for_added_item(item: T): void {
		for (const config of this.#index_configs) {
			switch (config.type) {
				case Index_Type.SINGLE: {
					const key = config.extractor(item);
					// Only index if the key isn't undefined (null is a valid key)
					if (key !== undefined) {
						this.single_indexes[config.key].set(key, item);
					}
					break;
				}
				case Index_Type.MULTI: {
					const keys = config.extractor(item);
					// Handle both single values and arrays of values
					if (keys === undefined) break;

					if (Array.isArray(keys)) {
						// Handle array of keys by adding to each one
						for (const key of keys) {
							if (key === undefined) continue;
							const collection = this.multi_indexes[config.key].get(key) || [];
							collection.push(item);
							this.multi_indexes[config.key].set(key, collection);
						}
					} else {
						// Handle single key
						const collection = this.multi_indexes[config.key].get(keys) || [];
						collection.push(item);
						this.multi_indexes[config.key].set(keys, collection);
					}
					break;
				}
				case Index_Type.DERIVED: {
					// Check if the item matches this derived index
					if (!config.matches || config.matches(item)) {
						const collection = this.derived_indexes[config.key];
						if (config.on_add) {
							// Use custom update function if provided
							config.on_add(collection, item, this);
						} else {
							// Default behavior: add item to end
							collection.push(item);
						}
					}
					break;
				}
			}
		}
	}

	/**
	 * Remove multiple items efficiently
	 */
	remove_many(ids: Array<Uuid>): number {
		if (!ids.length) return 0;

		// Use a Set for O(1) lookups
		const id_set = new Set(ids);
		let removed_count = 0;

		// First build a removal map to avoid repeated lookups
		const to_remove_items: Array<T> = [];

		// Identify items to remove
		for (let i = this.all.length - 1; i >= 0; i--) {
			const item = this.all[i];
			if (id_set.has(item.id)) {
				this.all.splice(i, 1); // Remove directly from array
				to_remove_items.push(item);
				removed_count++;
			}
		}

		// Exit early if nothing to remove
		if (removed_count === 0) return 0;

		// Clear removed items from indexes
		for (const item of to_remove_items) {
			this.by_id.delete(item.id);
			this.#update_indexes_for_removed_item(item);
		}

		return removed_count;
	}

	/**
	 * Update all indexes when an item is removed
	 */
	#update_indexes_for_removed_item(item: T): void {
		for (const config of this.#index_configs) {
			switch (config.type) {
				case Index_Type.SINGLE: {
					// For single indexes, we need to find any keys that might be referencing this item
					// We can't just rely on the current key from the extractor since the item may have changed
					const single_index = this.single_indexes[config.key];

					// Find any keys in the index that point to this item
					for (const [existing_key, mapped_item] of single_index.entries()) {
						if (mapped_item.id === item.id) {
							// We found a key referencing this item - now check if we should delete or update
							// Check if there's another item with the same key still in the collection
							const alternative_item = this.all.find(
								(i) => i.id !== item.id && config.extractor(i) === existing_key,
							);

							if (alternative_item) {
								// If another item with the same key exists, update the index to point to it
								single_index.set(existing_key, alternative_item);
							} else {
								// Otherwise remove the mapping entirely
								single_index.delete(existing_key);
							}
						}
					}
					break;
				}
				case Index_Type.MULTI: {
					// For multi-indexes, the logic is similar - we need to extract current keys
					const keys = config.extractor(item);
					if (keys === undefined) continue;

					if (Array.isArray(keys)) {
						// Handle array of keys
						for (const key of keys) {
							if (key === undefined) continue;
							const multi_index = this.multi_indexes[config.key];
							const collection = multi_index.get(key);

							if (collection) {
								const updated = collection.filter((i) => i.id !== item.id);
								if (updated.length === 0) {
									multi_index.delete(key);
								} else {
									multi_index.set(key, updated);
								}
							}
						}
					} else {
						// Handle single key
						const multi_index = this.multi_indexes[config.key];
						const collection = multi_index.get(keys);

						if (collection) {
							const updated = collection.filter((i) => i.id !== item.id);
							if (updated.length === 0) {
								multi_index.delete(keys);
							} else {
								multi_index.set(keys, updated);
							}
						}
					}
					break;
				}
				case Index_Type.DERIVED: {
					// Check if the item matches this derived index
					if (!config.matches || config.matches(item)) {
						const collection = this.derived_indexes[config.key];
						if (config.on_remove) {
							// Use custom update function if provided
							config.on_remove(collection, item, this);
						} else {
							// Default behavior: remove by ID
							const idx = collection.findIndex((i) => i.id === item.id);
							if (idx !== -1) {
								collection.splice(idx, 1);
							}
						}
					}
					break;
				}
			}
		}
	}

	/**
	 * Add an item to the collection and update all indexes
	 */
	add(item: T): T {
		// Add to the end of the array
		this.all.push(item);
		this.by_id.set(item.id, item);

		// Update all indexes
		this.#update_indexes_for_added_item(item);

		return item;
	}

	/**
	 * Add an item at the beginning of the collection
	 */
	add_first(item: T): T {
		// Add to beginning of array
		this.all.unshift(item);
		this.by_id.set(item.id, item);

		// Update all indexes
		this.#update_indexes_for_added_item(item);

		return item;
	}

	/**
	 * Insert an item at a specific position
	 */
	insert_at(item: T, index: number): T {
		if (index < 0 || index > this.all.length) {
			throw new Error(
				`Insert index ${index} out of bounds for collection of size ${this.all.length}`,
			);
		}

		if (index === 0) {
			return this.add_first(item);
		}

		if (index === this.all.length) {
			return this.add(item);
		}

		// Insert into array
		this.all.splice(index, 0, item);
		this.by_id.set(item.id, item);

		// Update all indexes
		this.#update_indexes_for_added_item(item);

		return item;
	}

	/**
	 * Remove an item by its ID and update all indexes
	 */
	remove(id: Uuid): boolean {
		const item = this.by_id.get(id);
		if (!item) return false;

		// Find the index of the item in the array
		const index = this.index_of(id);
		if (index === undefined) return false;

		// IMPORTANT: First update indexes, then remove from collection
		// This order matters for correct handling of duplicate keys
		this.#update_indexes_for_removed_item(item);

		// Now remove from array and by_id map
		this.all.splice(index, 1);
		this.by_id.delete(id);

		return true;
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
	 * Get the array index of an item by its ID
	 */
	index_of(id: Uuid): number | undefined {
		// Find the item in the array with linear search
		const item = this.by_id.get(id);
		if (!item) return undefined;

		// Scan the array to find the item
		for (let i = 0; i < this.all.length; i++) {
			if (this.all[i].id === id) {
				return i;
			}
		}

		// Item not found in array but exists in by_id (inconsistent state)
		return undefined;
	}

	/**
	 * Reorder items in the collection
	 */
	reorder(from_index: number, to_index: number): void {
		if (from_index === to_index) return;
		if (from_index < 0 || to_index < 0) return;
		if (from_index >= this.all.length || to_index >= this.all.length) return;

		// Get the item to move
		const item = this.all[from_index];

		// Remove from array and reinsert at new position
		this.all.splice(from_index, 1);
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

		// Clear all indexes
		for (const config of this.#index_configs) {
			switch (config.type) {
				case Index_Type.SINGLE:
					this.single_indexes[config.key].clear();
					break;
				case Index_Type.MULTI:
					this.multi_indexes[config.key].clear();
					break;
				case Index_Type.DERIVED:
					this.derived_indexes[config.key] = [];
					break;
			}
		}
	}

	/**
	 * Get all items matching a multi-indexed property value
	 */
	where(index_key: string, value: any): Array<T> {
		// Check if the index exists
		// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
		if (!this.multi_indexes[index_key]) {
			return [];
		}
		return [...(this.multi_indexes[index_key].get(value) || [])];
	}

	/**
	 * Get the first N items matching a multi-indexed property value
	 */
	first(index_key: string, value: any, limit: number): Array<T> {
		// Handle edge cases with limit
		if (limit <= 0) return [];

		const items = this.where(index_key, value);
		return items.slice(0, limit);
	}

	/**
	 * Get the latest N items matching a multi-indexed property value
	 */
	latest(index_key: string, value: any, limit: number): Array<T> {
		// Handle edge cases with limit
		if (limit <= 0) return [];

		const items = this.where(index_key, value);
		return items.slice(-Math.min(limit, items.length));
	}

	/**
	 * Get a derived index collection by its key
	 */
	get_derived(key: string): Array<T> {
		// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
		return this.derived_indexes[key] || [];
	}

	/**
	 * Find items related to a collection by a property reference
	 */
	related<S extends Record<string, any>>(
		items: Array<S> | undefined,
		property_name: string,
	): Array<T> {
		if (!items?.length) return [];

		const result: Array<T> = [];
		const seen_ids: Set<Uuid> = new Set(); // Prevent duplicates

		// Pre-compute path parts outside the loop for efficiency
		const has_complex_path = property_name.includes('.') || property_name.includes('[');
		const path_parts = has_complex_path ? property_name.split('.') : null;

		for (const item of items) {
			let foreign_key: Uuid | undefined;

			if (has_complex_path && path_parts) {
				foreign_key = this.#resolve_path(item, path_parts);
			} else {
				foreign_key = item[property_name];
			}

			if (foreign_key && !seen_ids.has(foreign_key)) {
				const related_item = this.by_id.get(foreign_key);
				if (related_item) {
					result.push(related_item);
					seen_ids.add(foreign_key);
				}
			}
		}

		return result;
	}

	/**
	 * Helper function to resolve a property path
	 */
	#resolve_path(obj: any, path_parts: Array<string>): any {
		let current: any = obj;

		for (let i = 0; i < path_parts.length && current != null; i++) {
			const part = path_parts[i];

			if (part.includes('[') && part.includes(']')) {
				const match = /^([^[]+)\[(\d+)\]$/.exec(part);
				if (match) {
					const [_, array_name, index_str] = match;
					const array = current[array_name];
					if (Array.isArray(array)) {
						const index = parseInt(index_str, 10);
						current = array[index];
					} else {
						return undefined;
					}
				}
			} else {
				current = current[part];
			}
		}

		return current;
	}

	/**
	 * Get an item by a single-value index
	 * Returns the item or throws if no item is found
	 */
	by<T_Key extends string>(index_key: T_Key, value: any): T {
		const item = this.single_indexes[index_key].get(value);
		if (!item) {
			throw new Error(`Item not found for index ${String(index_key)} with value ${String(value)}`);
		}
		return item;
	}

	/**
	 * Get an item by a single-value index, returning undefined if not found
	 */
	by_optional<T_Key extends string>(index_key: T_Key, value: any): T | undefined {
		// Check if the index exists first
		// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
		if (!this.single_indexes[index_key]) {
			return undefined;
		}
		return this.single_indexes[index_key].get(value);
	}

	/**
	 * Get items related through a foreign key relationship
	 * This efficiently uses the index to retrieve items in a single operation
	 *
	 * @param key The multi-index key that contains the relationship
	 * @param items Source items containing the IDs
	 * @param id_extractor Function to extract the foreign key ID from each source item
	 * @returns Array of related items
	 */
	related_by_index<S>(
		key: string,
		items: Array<S>,
		id_extractor: (item: S) => Uuid | undefined,
	): Array<T> {
		if (!items.length) return [];

		const result: Array<T> = [];
		const seen_ids: Set<string> = new Set();

		for (const item of items) {
			const id = id_extractor(item);
			if (!id || seen_ids.has(id)) continue;

			const related_items = this.multi_indexes[key].get(id);
			if (related_items?.length) {
				result.push(...related_items);
				seen_ids.add(id);
			}
		}

		return result;
	}
}
