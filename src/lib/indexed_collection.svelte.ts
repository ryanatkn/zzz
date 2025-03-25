import {SvelteMap} from 'svelte/reactivity';
import type {z} from 'zod';
import {DEV} from 'esm-env';

import {Uuid} from '$lib/zod_helpers.js';

// TODO optimize, particular the scans of `this.all`

// TODO think about this from the whole graph's POV, not just individual collections, for relationships/transactions
// consider a batch operations interface: "Add a transaction-like interface for batch operations to improve performance. Example: collection.batch().add(item1).remove(item2).commit()"

/**
 * Interface for objects that can be stored in an indexed collection
 */
export interface Indexed_Item {
	id: Uuid;
}

/**
 * String literals for index types
 */
export type Index_Type = 'single' | 'multi' | 'derived' | 'dynamic';

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
	compute: (collection: Indexed_Collection<T>) => T_Result;

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
	on_add?: (result: T_Result, item: T, collection: Indexed_Collection<T>) => T_Result;

	/** Optional function to update the index when an item is removed */
	on_remove?: (result: T_Result, item: T, collection: Indexed_Collection<T>) => T_Result;
}

export interface Indexed_Collection_Options<
	T extends Indexed_Item,
	T_Key_Single extends string = string,
	T_Key_Multi extends string = string,
	T_Key_Derived extends string = string,
	T_Key_Dynamic extends string = string,
> {
	indexes?: Array<Index_Definition<T>>;
	initial_items?: Array<T>;
	validate?: boolean;
	index_types?: {
		single?: Array<T_Key_Single>;
		multi?: Array<T_Key_Multi>;
		derived?: Array<T_Key_Derived>;
		dynamic?: Array<T_Key_Dynamic>;
	};
}

/**
 * A helper class for managing collections that need efficient lookups
 * with automatic index maintenance
 *
 * @param T - The type of items stored in the collection
 * @param T_Key_Single - Type-safe keys for single value indexes
 * @param T_Key_Multi - Type-safe keys for multi value indexes
 * @param T_Key_Derived - Type-safe keys for derived indexes
 * @param T_Key_Dynamic - Type-safe keys for dynamic function indexes
 */
export class Indexed_Collection<
	T extends Indexed_Item,
	T_Key_Single extends string = string,
	T_Key_Multi extends string = string,
	T_Key_Derived extends string = string,
	T_Key_Dynamic extends string = string,
> {
	// The main collection of items
	all: Array<T> = $state([]);

	// The primary index by id keyed by Uuid
	readonly by_id: SvelteMap<Uuid, T> = new SvelteMap();

	// Stores all index values (reactive)
	readonly indexes: Record<string, any> = $state({});

	// Map of index types for type safety and runtime checks
	readonly #index_types: Map<string, Index_Type> = new Map();

	// Store all index configs for reference
	#index_definitions: ReadonlyArray<Index_Definition<T>> = [];

	// Whether to validate indexes
	readonly #validate: boolean;

	constructor(
		options?: Indexed_Collection_Options<
			T,
			T_Key_Single,
			T_Key_Multi,
			T_Key_Derived,
			T_Key_Dynamic
		>,
	) {
		// Set validation flag (default to false)
		this.#validate = options?.validate ?? false;

		// Set up indexes based on provided configurations
		if (options?.indexes) {
			this.#index_definitions = options.indexes;

			// Initialize each index with its compute function
			for (const def of this.#index_definitions) {
				this.indexes[def.key] = def.compute(this);

				// Store the index type for type safety and runtime checks
				if (def.type) {
					this.#index_types.set(def.key, def.type);
				} else if (typeof this.indexes[def.key] === 'function') {
					this.#index_types.set(def.key, 'dynamic');
				} else if (this.indexes[def.key] instanceof Array) {
					this.#index_types.set(def.key, 'derived');
				} else if (
					this.indexes[def.key] instanceof Map && // also covers SvelteMap
					Array.isArray(
						[...this.indexes[def.key].values()].length > 0
							? [...this.indexes[def.key].values()][0]
							: [],
					)
				) {
					this.#index_types.set(def.key, 'multi');
				} else {
					this.#index_types.set(def.key, 'single');
				}
			}

			// Apply explicit type hints if provided
			if (options.index_types) {
				if (options.index_types.single) {
					for (const key of options.index_types.single) {
						this.#index_types.set(key, 'single');
					}
				}
				if (options.index_types.multi) {
					for (const key of options.index_types.multi) {
						this.#index_types.set(key, 'multi');
					}
				}
				if (options.index_types.derived) {
					for (const key of options.index_types.derived) {
						this.#index_types.set(key, 'derived');
					}
				}
				if (options.index_types.dynamic) {
					for (const key of options.index_types.dynamic) {
						this.#index_types.set(key, 'dynamic');
					}
				}
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
	get_index<T_Result = any>(
		key: T_Key_Single | T_Key_Multi | T_Key_Derived | T_Key_Dynamic,
	): T_Result {
		return this.indexes[key];
	}

	/**
	 * Get a single-value index with proper typing
	 */
	single_index<V>(key: T_Key_Single): SvelteMap<any, V> {
		this.#ensure_index(key, 'single');
		return this.indexes[key];
	}

	/**
	 * Get a multi-value index with proper typing
	 */
	multi_index<V>(key: T_Key_Multi): SvelteMap<any, Array<V>> {
		this.#ensure_index(key, 'multi');
		return this.indexes[key];
	}

	/**
	 * Get a derived index with proper typing
	 */
	derived_index<V>(key: T_Key_Derived): Array<V> {
		this.#ensure_index(key, 'derived');
		return this.indexes[key];
	}

	/**
	 * Get a dynamic (function) index with proper typing
	 */
	dynamic_index<V, Q = any>(key: T_Key_Dynamic): (query: Q) => V {
		this.#ensure_index(key, 'dynamic');
		return this.indexes[key];
	}

	/**
	 * Ensures that the index exists and is of the expected type
	 * @param key - The index key to check
	 * @param expected_type - The expected type of the index
	 * @throws Error if index doesn't exist or has wrong type
	 */
	#ensure_index(key: string, expected_type: Index_Type): void {
		const index = this.indexes[key];
		if (index === undefined) {
			throw new Error(`Index not found: ${key}`);
		}

		const actual_type = this.#index_types.get(key);
		if (actual_type !== expected_type) {
			throw new Error(
				`Index type mismatch: ${key} is a ${actual_type || 'unknown'} index, not a ${expected_type} index`,
			);
		}
	}

	/**
	 * Query an index with parameters
	 *
	 * This method is type-aware when the index has a query_schema that defines T_Query
	 */
	query<T_Result = any, T_Query = any>(
		key: T_Key_Single | T_Key_Multi | T_Key_Derived | T_Key_Dynamic,
		query: T_Query,
	): T_Result {
		const index = this.indexes[key];
		if (!index) return undefined as unknown as T_Result;

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
			return index.get(query); // also covers SvelteMap
		}
		if (typeof index === 'function') {
			return index(query);
		}

		// For array indexes or other types, return the whole index
		return index;
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
			// Update primary id index
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
		const {by_id} = this;

		if (by_id.has(item.id)) {
			if (DEV) console.error('Item with this id already exists in the collection: ' + item.id);
			return by_id.get(item.id)!;
		}

		by_id.set(item.id, item);

		// Add to the end of the array
		this.all.push(item);

		// Update all indexes
		this.#update_indexes_for_added_item(item);

		return item;
	}

	// TODO BLOCK @many maybe delete?  for `add`
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
	 * Remove an item by its id and update all indexes
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
	 * Get an item by its id
	 */
	get(id: Uuid): T | undefined {
		return this.by_id.get(id);
	}

	/**
	 * Check if the collection has an item with the given id
	 */
	has(id: Uuid): boolean {
		return this.by_id.has(id);
	}

	/**
	 * Get the array index of an item by its id
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
	 * Type-safe version that uses the T_Key_Multi generic parameter
	 */
	where<V = any>(index_key: T_Key_Multi, value: V): Array<T> {
		this.#ensure_index(index_key, 'multi');
		const index = this.indexes[index_key];
		return [...(index.get(value) || [])];
	}

	/**
	 * Get the first N items matching a multi-indexed property value
	 * Type-safe version that uses the T_Key_Multi generic parameter
	 */
	first<V = any>(index_key: T_Key_Multi, value: V, limit: number): Array<T> {
		// Handle edge cases with limit
		if (limit <= 0) return [];

		const items = this.where<V>(index_key, value);
		return items.slice(0, limit);
	}

	/**
	 * Get the latest N items matching a multi-indexed property value
	 * Type-safe version that uses the T_Key_Multi generic parameter
	 */
	latest<V = any>(index_key: T_Key_Multi, value: V, limit: number): Array<T> {
		// Handle edge cases with limit
		if (limit <= 0) return [];

		const items = this.where<V>(index_key, value);
		return items.slice(-Math.min(limit, items.length));
	}

	/**
	 * Get a derived collection by its key
	 * Type-safe version that uses the T_Key_Derived generic parameter
	 */
	get_derived(key: T_Key_Derived): Array<T> {
		this.#ensure_index(key, 'derived');
		return this.indexes[key];
	}

	/**
	 * Get an item by a single-value index
	 * Returns the item or throws if no item is found
	 * Type-safe version that uses the T_Key_Single generic parameter
	 */
	by<V = any>(index_key: T_Key_Single, value: V): T {
		// This will throw if index doesn't exist or has wrong type
		this.#ensure_index(index_key, 'single');

		const index = this.indexes[index_key];
		const item = index.get(value);

		if (!item) {
			throw new Error(`Item not found for index ${index_key} with value ${String(value)}`);
		}
		return item;
	}

	/**
	 * Get an item by a single-value index, returning undefined if not found
	 * Type-safe version that uses the T_Key_Single generic parameter
	 */
	by_optional<V = any>(index_key: T_Key_Single, value: V): T | undefined {
		this.#ensure_index(index_key, 'single');
		return this.indexes[index_key].get(value);
	}
}
