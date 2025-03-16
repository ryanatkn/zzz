import {SvelteMap} from 'svelte/reactivity';
import {Uuid} from '$lib/zod_helpers.js';

// TODO need better caching

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

export type Index_Value_Types<K extends string> = Record<K, any>;

export interface Indexed_Collection_Options<
	T extends Indexed_Item,
	K extends string,
	V extends Index_Value_Types<K> = Record<K, any>,
> {
	indexes?: Array<Index_Config<T, K, V[K]>>;
	initial_items?: Array<T>;
}

/**
 * A helper class for managing collections that need efficient lookups
 * with automatic index maintenance
 */
export class Indexed_Collection<
	T extends Indexed_Item,
	K extends string = never,
	V extends Index_Value_Types<K> = Record<K, any>,
> {
	// The main collection of items
	all: Array<T> = $state([]); // TODO BLOCK look at all usage of this for indexing opportunities (needs new features to handle some cases)

	// The primary index by ID now keyed by Uuid instead of string
	readonly by_id: SvelteMap<Uuid, T> = new SvelteMap();

	// Index position map for O(1) position lookups.
	// Named `position_index` to avoid naming conflicts
	// with the other kind of index that this class is named after.
	// TODO Maybe `Indexed_Collection` could be `Cached_Collection` or `Cached_Cells` or `Cell_Collection`?
	readonly position_index: SvelteMap<Uuid, number> = new SvelteMap();

	// Additional single-value indexes (one key maps to one item)
	readonly single_indexes: Partial<Record<K, SvelteMap<any, T>>> = {};

	// Additional multi-value indexes (one key maps to many items)
	readonly multi_indexes: Partial<Record<K, SvelteMap<any, Array<T>>>> = {};

	#configs: Array<Index_Config<T, K, any>> = [];

	constructor(options?: Indexed_Collection_Options<T, K, V>) {
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
		const position = this.all.length;
		this.all.push(item);
		this.by_id.set(item.id, item);
		this.position_index.set(item.id, position);

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
		this.position_index.set(item.id, 0);

		// Update positions for all existing items after the inserted one (oof for perf)
		for (let i = 1; i < this.all.length; i++) {
			this.position_index.set(this.all[i].id, i);
		}

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

		const index = this.position_index.get(id);
		if (index === undefined) return false;

		this.all.splice(index, 1);
		this.by_id.delete(id);
		this.position_index.delete(id);

		// Update positions for all items after the removed one (oof)
		for (let i = index; i < this.all.length; i++) {
			this.position_index.set(this.all[i].id, i);
		}

		// Update all additional indexes
		for (const config of this.#configs) {
			const key = config.extractor(item);
			if (key == null) continue;
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
	 * Reorder items in the collection
	 */
	reorder(from_index: number, to_index: number): void {
		if (from_index === to_index) return;
		if (from_index < 0 || to_index < 0) return;
		if (from_index >= this.all.length || to_index >= this.all.length) return;

		// Perform the reorder
		const [item] = this.all.splice(from_index, 1);
		this.all.splice(to_index, 0, item);

		// Update position index for affected items
		const start = Math.min(from_index, to_index);
		const end = Math.max(from_index, to_index);

		for (let i = start; i <= end; i++) {
			this.position_index.set(this.all[i].id, i);
		}
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
		this.position_index.clear();

		// Clear all additional indexes
		for (const config of this.#configs) {
			if (config.multi) {
				this.multi_indexes[config.key]!.clear();
			} else {
				this.single_indexes[config.key]!.clear();
			}
		}
	}

	/**
	 * Get all items matching an indexed property value
	 *
	 * @param index_key The indexed property name
	 * @param value The value to filter by
	 */
	where<Key extends K>(index_key: Key, value: V[Key]): Array<T> {
		const multi_index = this.multi_indexes[index_key];
		if (multi_index) {
			return [...(multi_index.get(value) || [])];
		}

		const single_index = this.single_indexes[index_key];
		if (single_index) {
			const item = single_index.get(value);
			return item ? [item] : [];
		}

		return [];
	}

	/**
	 * Get the first N items matching an indexed property value
	 *
	 * @param index_key The indexed property name
	 * @param value The value to filter by
	 * @param limit Maximum number of items to return
	 */
	first<Key extends K>(index_key: Key, value: V[Key], limit: number): Array<T> {
		// Handle edge cases with limit
		if (limit <= 0) return [];

		const items = this.where(index_key, value);
		return items.slice(0, limit);
	}

	/**
	 * Get the latest N items matching an indexed property value
	 *
	 * @param index_key The indexed property name
	 * @param value The value to filter by
	 * @param limit Maximum number of items to return
	 */
	latest<Key extends K>(index_key: Key, value: V[Key], limit: number): Array<T> {
		// Handle edge cases with limit
		if (limit <= 0) return [];

		const items = this.where(index_key, value);
		return items.slice(-Math.min(limit, items.length));
	}

	// TODO make this
	/**
	 * Find related items by a property reference
	 *
	 * @param items Source items containing references
	 * @param property_name The property containing the reference ID
	 */
	related<S extends Record<string, any>>(
		items: Array<S> | undefined,
		property_name: string,
	): Array<T> {
		if (!items?.length) return [];

		const result: Array<T> = [];
		for (const item of items) {
			if (property_name.includes('.') || property_name.includes('[')) {
				const path_parts = property_name.split('.');
				let current: any = item;
				for (let i = 0; i < path_parts.length; i++) {
					if (current === null) break;
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
								current = null;
								break;
							}
						}
					} else {
						current = current[part];
					}
				}
				if (current != null) {
					const foreign_key = current;
					const related_item = this.by_id.get(foreign_key);
					if (related_item) {
						result.push(related_item);
					}
				}
			} else {
				const foreign_key = item[property_name];
				if (foreign_key) {
					const related_item = this.by_id.get(foreign_key);
					if (related_item) {
						result.push(related_item);
					}
				}
			}
		}
		return result;
	}

	// TODO add `many_by` for arrays?
	/**
	 * Get an item by a single-value index
	 */
	by<Key extends K>(index_key: Key, value: V[Key]): T | undefined {
		return this.single_indexes[index_key]?.get(value);
	}
}
