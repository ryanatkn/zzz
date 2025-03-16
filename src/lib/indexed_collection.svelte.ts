import {SvelteMap} from 'svelte/reactivity';
import type {z} from 'zod';

import {Uuid} from '$lib/zod_helpers.js';

// TODO consider a batch operations interface: "Add a transaction-like interface for batch operations to improve performance. Example: collection.batch().add(item1).remove(item2).commit()"

/**
 * Interface for objects that can be stored in an indexed collection
 */
export interface Indexed_Item {
	id: Uuid;
}

/**
 * String literals for index types
 */
export type Index_Type = 'single' | 'multi' | 'derived';

/**
 * Generic index definition with full flexibility
 */
export interface Index_Definition<T extends Indexed_Item, T_Result = any, T_Query = any> {
	/** Unique identifier for this index */
	key: string;

	/** Optional index type for simpler creation */
	type?: Index_Type;

	/** Optional extractor function for single/multi indexes */
	extractor?: (item: T) => any;

	/** Function to compute the index value from scratch */
	compute: (collection: Indexed_Collection<T, any>) => T_Result;

	/**
	 * Schema for validating query parameters
	 * This also defines the type of queries this index accepts
	 */
	query_schema?: z.ZodType<T_Query>;

	/**
	 * Schema for validating the computed result
	 * This defines the return type of the index lookups
	 */
	result_schema: z.ZodType<T_Result>;

	/** Optional predicate to determine if an item is relevant to this index */
	matches?: (item: T) => boolean;

	/** Optional function to update the index when an item is added */
	on_add?: (result: T_Result, item: T, collection: Indexed_Collection<T, any>) => T_Result;

	/** Optional function to update the index when an item is removed */
	on_remove?: (result: T_Result, item: T, collection: Indexed_Collection<T, any>) => T_Result;
}

export interface Indexed_Collection_Options<T extends Indexed_Item> {
	indexes?: Array<Index_Definition<T>>; // TODO @many should we be passing through `, T_Result = any, T_Query = any` here?
	initial_items?: Array<T>;
	validate?: boolean; // Optional validation flag
}

/**
 * A helper class for managing collections that need efficient lookups
 * with automatic index maintenance
 *
 * @param T - The type of items stored in the collection
 * @param K - Type-safe keys for available indexes
 */
export class Indexed_Collection<T extends Indexed_Item, K extends string = string> {
	// The main collection of items
	all: Array<T> = $state([]);

	// The primary index by ID keyed by Uuid
	readonly by_id: SvelteMap<Uuid, T> = new SvelteMap();

	// Stores all index values (reactive)
	readonly indexes: Record<string, any> = $state({});

	// Store all index configs for reference - using tuple typing for better type safety
	#index_definitions: ReadonlyArray<Index_Definition<T>> = []; // TODO @many should we be passing through `, T_Result = any, T_Query = any` here?

	// Whether to validate indexes
	readonly #validate: boolean;

	constructor(options?: Indexed_Collection_Options<T>) {
		// Set validation flag (default to false)
		this.#validate = options?.validate ?? false;

		// Set up indexes based on provided configurations
		if (options?.indexes) {
			this.#index_definitions = options.indexes;

			// Initialize each index with its compute function
			for (const def of this.#index_definitions) {
				this.indexes[def.key] = def.compute(this);
			}
		}

		// Add any initial items
		if (options?.initial_items) {
			this.add_many(options.initial_items);
		}
	}

	toJSON(): Array<any> {
		return $state.snapshot(this.all);
	}

	/**
	 * Get a typed index value by key
	 */
	get_index<T_Result = any>(key: K): T_Result {
		return this.indexes[key as string];
	}

	/**
	 * Get a single-value index with proper typing
	 */
	single_index<V>(key: K): SvelteMap<any, V> {
		return this.indexes[key as string] as SvelteMap<any, V>;
	}

	/**
	 * Get a multi-value index with proper typing
	 */
	multi_index<V>(key: K): SvelteMap<any, Array<V>> {
		return this.indexes[key as string] as SvelteMap<any, Array<V>>;
	}

	/**
	 * Get a derived index with proper typing
	 */
	derived_index<V>(key: K): Array<V> {
		return this.indexes[key as string] as Array<V>;
	}

	/**
	 * Get a dynamic (function) index with proper typing
	 */
	dynamic_index<V, Q = any>(key: K): (query: Q) => V {
		return this.indexes[key as string] as (query: Q) => V;
	}

	/**
	 * Query an index with parameters
	 *
	 * This method is type-aware when the index has a query_schema that defines T_Query
	 */
	query<T_Result = any, T_Query = any>(key: K, query: T_Query): T_Result {
		const index = this.indexes[key as string];
		const index_def = this.#index_definitions.find((def) => def.key === key);

		// Validate input if schema exists
		if (this.#validate && index_def?.query_schema) {
			try {
				index_def.query_schema.parse(query);
			} catch (error) {
				console.error(`Query validation failed for index ${key}:`, error);
			}
		}

		// Handle different common index types
		if (index instanceof Map) {
			return index.get(query) as T_Result;
		}
		if (index instanceof SvelteMap) {
			return index.get(query) as T_Result;
		}
		if (typeof index === 'function') {
			return index(query) as T_Result;
		}

		// For array indexes or other types, return the whole index
		// Consumers will need to filter it themselves
		return index as T_Result;
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
		for (const def of this.#index_definitions) {
			if (def.on_add && (!def.matches || def.matches(item))) {
				const result = def.on_add(this.indexes[def.key], item, this);

				// Validate result if needed
				if (this.#validate) {
					try {
						def.result_schema.parse(result);
					} catch (error) {
						console.error(`Index ${def.key} validation failed on add:`, error);
					}
				}

				this.indexes[def.key] = result;
			}
		}
	}

	/**
	 * Update all indexes when an item is removed
	 */
	#update_indexes_for_removed_item(item: T): void {
		for (const def of this.#index_definitions) {
			if (def.on_remove && (!def.matches || def.matches(item))) {
				const result = def.on_remove(this.indexes[def.key], item, this);

				// Validate result if needed
				if (this.#validate) {
					try {
						def.result_schema.parse(result);
					} catch (error) {
						console.error(`Index ${def.key} validation failed on remove:`, error);
					}
				}

				this.indexes[def.key] = result;
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
		for (const def of this.#index_definitions) {
			this.indexes[def.key] = def.compute(this);
		}
	}

	/**
	 * Get all items matching a multi-indexed property value
	 * Type-safe version that uses the K generic parameter
	 */
	where<V = any>(index_key: K, value: V): Array<T> {
		const index = this.indexes[index_key as string];
		if (!index) return [];

		if (index instanceof Map || index instanceof SvelteMap) {
			return [...(index.get(value) || [])];
		}

		// Fallback - treat as array
		return [];
	}

	/**
	 * Get the first N items matching a multi-indexed property value
	 * Type-safe version that uses the K generic parameter
	 */
	first<V = any>(index_key: K, value: V, limit: number): Array<T> {
		// Handle edge cases with limit
		if (limit <= 0) return [];

		const items = this.where<V>(index_key, value);
		return items.slice(0, limit);
	}

	/**
	 * Get the latest N items matching a multi-indexed property value
	 * Type-safe version that uses the K generic parameter
	 */
	latest<V = any>(index_key: K, value: V, limit: number): Array<T> {
		// Handle edge cases with limit
		if (limit <= 0) return [];

		const items = this.where<V>(index_key, value);
		return items.slice(-Math.min(limit, items.length));
	}

	/**
	 * Get a derived collection by its key
	 * Type-safe version that uses the K generic parameter
	 */
	get_derived(key: K): Array<T> {
		return this.indexes[key as string] || [];
	}

	/**
	 * Get an item by a single-value index
	 * Returns the item or throws if no item is found
	 * Type-safe version that uses the K generic parameter
	 */
	by<V = any>(index_key: K, value: V): T {
		const index = this.indexes[index_key as string];
		if (!index) {
			throw new Error(`Index not found: ${index_key}`);
		}

		const item = index instanceof Map || index instanceof SvelteMap ? index.get(value) : undefined;

		if (!item) {
			throw new Error(`Item not found for index ${index_key} with value ${String(value)}`);
		}
		return item;
	}

	/**
	 * Get an item by a single-value index, returning undefined if not found
	 * Type-safe version that uses the K generic parameter
	 */
	by_optional<V = any>(index_key: K, value: V): T | undefined {
		const index = this.indexes[index_key as string];
		if (!index) return undefined;

		return index instanceof Map || index instanceof SvelteMap ? index.get(value) : undefined;
	}
}
