import {SvelteMap} from 'svelte/reactivity';
import type {z} from 'zod';
import {DEV} from 'esm-env';

import {Uuid} from '$lib/zod_helpers.js';

// TODO the API is nowhere near done, this is just a proof of concept

// TODO think about this from the whole graph's POV, not just individual collections, for relationships/transactions

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
	onadd?: (result: T_Result, item: T, collection: Indexed_Collection<T>) => T_Result;

	/** Optional function to update the index when an item is removed */
	onremove?: (result: T_Result, item: T, collection: Indexed_Collection<T>) => T_Result;
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
	/** The full collection keyed by Uuid. */
	readonly by_id: SvelteMap<Uuid, T> = new SvelteMap();

	/** Get the current count of items. */
	readonly size: number = $derived(this.by_id.size);

	// TODO ideally I think this would leverage derived? need to ensure we have the right lazy perf characteristics
	/** Stores all index values in a reactive object. */
	readonly indexes: Record<string, any> = $state({});

	// Map of index types for type safety and runtime checks
	readonly #index_types: Map<string, Index_Type> = new Map();

	// Store all index configs for reference
	readonly #index_definitions: ReadonlyArray<Index_Definition<T>> = [];

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
		return $state.snapshot([...this.by_id.values()]);
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
	single_index(key: T_Key_Single): SvelteMap<any, T> {
		this.#ensure_index(key, 'single');
		return this.indexes[key];
	}

	/**
	 * Get a multi-value index with proper typing
	 */
	multi_index(key: T_Key_Multi): SvelteMap<any, Array<T>> {
		this.#ensure_index(key, 'multi');
		return this.indexes[key];
	}

	/**
	 * Get a derived index with proper typing
	 */
	derived_index(key: T_Key_Derived): Array<T> {
		this.#ensure_index(key, 'derived');
		return this.indexes[key];
	}

	/**
	 * Get a dynamic (function) index with proper typing
	 */
	dynamic_index<Q = any>(key: T_Key_Dynamic): (query: Q) => T {
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

		// Add all items to the collection
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
			if (def.onadd && (!def.matches || def.matches(item))) {
				const result = def.onadd(this.indexes[def.key], item, this);

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
			if (def.onremove && (!def.matches || def.matches(item))) {
				const result = def.onremove(this.indexes[def.key], item, this);

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

		// Update indexes first before removing the item
		this.#update_indexes_for_removed_item(item);

		// Now remove from by_id map
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

		// Build a list of items to remove
		const to_remove_items: Array<T> = [];

		// Identify items to remove
		for (const id of id_set) {
			const item = this.by_id.get(id);
			if (item) {
				to_remove_items.push(item);
				removed_count++;
			}
		}

		// Exit early if nothing to remove
		if (removed_count === 0) return 0;

		// Clear removed items from indexes first
		for (const item of to_remove_items) {
			this.#update_indexes_for_removed_item(item);
		}

		// Then remove from the main collection
		for (const item of to_remove_items) {
			this.by_id.delete(item.id);
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
	 * Clear all items and reset indexes
	 */
	clear(): void {
		this.by_id.clear();

		// Clear all indexes
		for (const def of this.#index_definitions) {
			this.indexes[def.key] = def.compute(this);
		}
	}

	// TODO `V = any` needs to be typesafe to the key/value pair

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
