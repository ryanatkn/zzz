import {SvelteMap} from 'svelte/reactivity';
import {Uuid} from '$lib/zod_helpers.js';

/**
 * Interface for objects that can be stored in an indexed collection
 */
export interface Indexed_Item {
	id: Uuid;
}

/**
 * Type-safe configuration for single-value indexes
 */
export interface Single_Index_Config<T, K extends string, V> {
	key: K;
	extractor: (item: T) => V;
}

/**
 * Type-safe configuration for multi-value indexes
 */
export interface Multi_Index_Config<T, K extends string, V> {
	key: K;
	extractor: (item: T) => V;
}

export type Index_Value_Types<T_Key_Single extends string, T_Key_Multi extends string> = Record<
	T_Key_Single | T_Key_Multi,
	any
>;

export interface Indexed_Collection_Options<
	T extends Indexed_Item,
	T_Key_Single extends string = never,
	T_Key_Multi extends string = never,
	V extends Index_Value_Types<T_Key_Single, T_Key_Multi> = Index_Value_Types<
		T_Key_Single,
		T_Key_Multi
	>,
> {
	single_indexes?: Array<Single_Index_Config<T, T_Key_Single, V[T_Key_Single]>>;
	multi_indexes?: Array<Multi_Index_Config<T, T_Key_Multi, V[T_Key_Multi]>>;
	initial_items?: Array<T>;
}

/**
 * A helper class for managing collections that need efficient lookups
 * with automatic index maintenance
 */
export class Indexed_Collection<
	T extends Indexed_Item,
	T_Key_Single extends string = never,
	T_Key_Multi extends string = never,
	V extends Index_Value_Types<T_Key_Single, T_Key_Multi> = Index_Value_Types<
		T_Key_Single,
		T_Key_Multi
	>,
> {
	// The main collection of items
	all: Array<T> = $state([]);

	// The primary index by ID keyed by Uuid
	readonly by_id: SvelteMap<Uuid, T> = new SvelteMap();

	// Single-value indexes (one key maps to one item)
	readonly single_indexes: Record<T_Key_Single, SvelteMap<any, T>> = {} as Record<
		T_Key_Single,
		SvelteMap<any, T>
	>;

	// Multi-value indexes (one key maps to many items)
	readonly multi_indexes: Record<T_Key_Multi, SvelteMap<any, Array<T>>> = {} as Record<
		T_Key_Multi,
		SvelteMap<any, Array<T>>
	>;

	#single_configs: Array<Single_Index_Config<T, T_Key_Single, any>> = [];
	#multi_configs: Array<Multi_Index_Config<T, T_Key_Multi, any>> = [];

	constructor(options?: Indexed_Collection_Options<T, T_Key_Single, T_Key_Multi, V>) {
		// Set up single indexes
		if (options?.single_indexes) {
			this.#single_configs = options.single_indexes;

			// Initialize the index maps
			for (const config of this.#single_configs) {
				this.single_indexes[config.key] = new SvelteMap();
			}
		}

		// Set up multi indexes
		if (options?.multi_indexes) {
			this.#multi_configs = options.multi_indexes;

			// Initialize the index maps
			for (const config of this.#multi_configs) {
				this.multi_indexes[config.key] = new SvelteMap();
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

			// Update secondary single indexes
			for (const config of this.#single_configs) {
				const key = config.extractor(item);
				if (key !== undefined && key !== null) {
					this.single_indexes[config.key].set(key, item);
				}
			}

			// Update secondary multi indexes
			for (const config of this.#multi_configs) {
				const key = config.extractor(item);
				if (key !== undefined && key !== null) {
					const collection = this.multi_indexes[config.key].get(key) || [];
					collection.push(item);
					this.multi_indexes[config.key].set(key, collection);
				}
			}
		}

		return items;
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
			// Clear from primary ID index
			this.by_id.delete(item.id);

			// Update secondary single indexes
			for (const config of this.#single_configs) {
				const key = config.extractor(item);
				if (key == null) continue;

				const single_index = this.single_indexes[config.key];
				const mapped_item = single_index.get(key);

				if (mapped_item && mapped_item.id === item.id) {
					single_index.delete(key);
				}
			}

			// Update secondary multi indexes
			for (const config of this.#multi_configs) {
				const key = config.extractor(item);
				if (key == null) continue;

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
		}

		return removed_count;
	}

	/**
	 * Add an item to the collection and update all indexes
	 */
	add(item: T): T {
		// Add to the end of the array
		this.all.push(item);
		this.by_id.set(item.id, item);

		// Update all single indexes
		for (const config of this.#single_configs) {
			const key = config.extractor(item);
			if (key !== undefined && key !== null) {
				this.single_indexes[config.key].set(key, item);
			}
		}

		// Update all multi indexes
		for (const config of this.#multi_configs) {
			const key = config.extractor(item);
			if (key !== undefined && key !== null) {
				const collection = this.multi_indexes[config.key].get(key) || [];
				collection.push(item);
				this.multi_indexes[config.key].set(key, collection);
			}
		}

		return item;
	}

	/**
	 * Add an item at the beginning of the collection
	 */
	add_first(item: T): T {
		// Add to beginning of array
		this.all.unshift(item);
		this.by_id.set(item.id, item);

		// Update single indexes
		for (const config of this.#single_configs) {
			const key = config.extractor(item);
			if (key !== undefined && key !== null) {
				this.single_indexes[config.key].set(key, item);
			}
		}

		// Update multi indexes
		for (const config of this.#multi_configs) {
			const key = config.extractor(item);
			if (key !== undefined && key !== null) {
				const collection = this.multi_indexes[config.key].get(key) || [];
				collection.unshift(item);
				this.multi_indexes[config.key].set(key, collection);
			}
		}

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

		// Update single indexes
		for (const config of this.#single_configs) {
			const key = config.extractor(item);
			if (key !== undefined && key !== null) {
				this.single_indexes[config.key].set(key, item);
			}
		}

		// Update multi indexes
		for (const config of this.#multi_configs) {
			const key = config.extractor(item);
			if (key !== undefined && key !== null) {
				const collection = this.multi_indexes[config.key].get(key) || [];
				collection.push(item);
				this.multi_indexes[config.key].set(key, collection);
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
		const index = this.index_of(id);
		if (index === undefined) return false;

		// Remove from array
		this.all.splice(index, 1);
		this.by_id.delete(id);

		// Update single indexes
		for (const config of this.#single_configs) {
			const key = config.extractor(item);
			if (key == null) continue;

			const single_index = this.single_indexes[config.key];
			const mapped_item = single_index.get(key);

			if (mapped_item && mapped_item.id === id) {
				single_index.delete(key);
			}
		}

		// Update multi indexes
		for (const config of this.#multi_configs) {
			const key = config.extractor(item);
			if (key == null) continue;

			const multi_index = this.multi_indexes[config.key];
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
		}

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

		// Clear all single indexes
		for (const config of this.#single_configs) {
			this.single_indexes[config.key].clear();
		}

		// Clear all multi indexes
		for (const config of this.#multi_configs) {
			this.multi_indexes[config.key].clear();
		}
	}

	/**
	 * Get all items matching a multi-indexed property value
	 *
	 * @param index_key The indexed property name
	 * @param value The value to filter by
	 */
	where<T_Key extends T_Key_Multi>(index_key: T_Key, value: V[T_Key]): Array<T> {
		return [...(this.multi_indexes[index_key].get(value) || [])];
	}

	/**
	 * Get the first N items matching a multi-indexed property value
	 *
	 * @param index_key The indexed property name
	 * @param value The value to filter by
	 * @param limit Maximum number of items to return
	 */
	first<T_Key extends T_Key_Multi>(index_key: T_Key, value: V[T_Key], limit: number): Array<T> {
		// Handle edge cases with limit
		if (limit <= 0) return [];

		const items = this.where(index_key, value);
		return items.slice(0, limit);
	}

	/**
	 * Get the latest N items matching a multi-indexed property value
	 *
	 * @param index_key The indexed property name
	 * @param value The value to filter by
	 * @param limit Maximum number of items to return
	 */
	latest<T_Key extends T_Key_Multi>(index_key: T_Key, value: V[T_Key], limit: number): Array<T> {
		// Handle edge cases with limit
		if (limit <= 0) return [];

		const items = this.where(index_key, value);
		return items.slice(-Math.min(limit, items.length));
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
	by<T_Key extends T_Key_Single>(index_key: T_Key, value: V[T_Key]): T {
		const item = this.single_indexes[index_key].get(value);
		if (!item) {
			throw new Error(`Item not found for index ${String(index_key)} with value ${String(value)}`);
		}
		return item;
	}

	/**
	 * Get an item by a single-value index, returning undefined if not found
	 */
	by_optional<T_Key extends T_Key_Single>(index_key: T_Key, value: V[T_Key]): T | undefined {
		return this.single_indexes[index_key].get(value);
	}
}
