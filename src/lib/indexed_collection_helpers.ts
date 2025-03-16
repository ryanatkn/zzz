import {SvelteMap} from 'svelte/reactivity';
import {z} from 'zod';

import type {
	Indexed_Item,
	Index_Definition,
	Indexed_Collection,
} from '$lib/indexed_collection.svelte.js';

/**
 * Common options interface for all index types
 */
export interface Index_Options<T extends Indexed_Item> {
	/** Optional predicate to determine if an item is relevant to this index */
	matches?: (item: T) => boolean;

	/** Optional schema for output validation (if not provided, a default will be used) */
	result_schema?: z.ZodType;
}

/**
 * Options for single-value indexes
 */
export interface Single_Index_Options<T extends Indexed_Item, K> extends Index_Options<T> {
	/** Schema for input validation and typing */
	query_schema?: z.ZodType<K>;
}

/**
 * Create a single-value index (one key maps to one item)
 */
export function create_single_index<T extends Indexed_Item, K = any>(
	key: string,
	extractor: (item: T) => K,
	query_schema?: z.ZodType<K>,
	options?: Single_Index_Options<T, K>,
): Index_Definition<T, SvelteMap<K, T>, K> {
	// Create the default output schema if not provided
	const result_schema =
		options?.result_schema || z.custom<SvelteMap<K, T>>((val) => val instanceof SvelteMap);

	return {
		key,
		type: 'single',
		extractor,
		query_schema: query_schema || (z.any() as z.ZodType<K>),
		matches: options?.matches,
		result_schema,
		compute: (collection) => {
			const map: SvelteMap<K, T> = new SvelteMap();
			for (const item of collection.all) {
				if (options?.matches && !options.matches(item)) continue;

				const extract_key = extractor(item);
				if (extract_key !== undefined) {
					map.set(extract_key, item);
				}
			}
			return map;
		},
		on_add: (map, item) => {
			if (options?.matches && !options.matches(item)) return map;

			const extract_key = extractor(item);
			if (extract_key !== undefined) {
				map.set(extract_key, item);
			}
			return map;
		},
		on_remove: (map, item, collection) => {
			if (options?.matches && !options.matches(item)) return map;

			const extract_key = extractor(item);
			if (extract_key !== undefined && map.get(extract_key) === item) {
				// This item is currently indexed - find if there's another item with the same key
				const items_with_same_key = collection.all.filter(
					(other) => other.id !== item.id && extractor(other) === extract_key,
				);

				if (items_with_same_key.length > 0) {
					// Found another item with the same key - use the first one
					map.set(extract_key, items_with_same_key[0]);
				} else {
					// No other items with this key - delete the entry
					map.delete(extract_key);
				}
			}
			return map;
		},
	};
}

/**
 * Options for multi-value indexes
 */
export interface Multi_Index_Options<T extends Indexed_Item, K> extends Index_Options<T> {
	/** Schema for input validation and typing */
	query_schema?: z.ZodType<K>;

	/** Optional sort function for items in each bucket */
	sort?: (a: T, b: T) => number;
}

/**
 * Create a multi-value index (one key maps to many items)
 */
export function create_multi_index<T extends Indexed_Item, K = any>(
	key: string,
	extractor: (item: T) => K | Array<K> | undefined,
	query_schema?: z.ZodType<K>,
	options?: Multi_Index_Options<T, K>,
): Index_Definition<T, SvelteMap<K, Array<T>>, K> {
	// Create the default output schema if not provided
	const result_schema =
		options?.result_schema || z.custom<SvelteMap<K, Array<T>>>((val) => val instanceof SvelteMap);

	return {
		key,
		type: 'multi',
		extractor,
		query_schema: query_schema || (z.any() as z.ZodType<K>),
		matches: options?.matches,
		result_schema,
		compute: (collection) => {
			const map: SvelteMap<K, Array<T>> = new SvelteMap();
			for (const item of collection.all) {
				if (options?.matches && !options.matches(item)) continue;

				const keys = extractor(item);
				if (keys === undefined) continue;

				if (Array.isArray(keys)) {
					for (const k of keys) {
						if (k === undefined) continue;
						const collection = map.get(k) || [];
						collection.push(item);
						map.set(k, collection);
					}
				} else {
					const collection = map.get(keys) || [];
					collection.push(item);
					map.set(keys, collection);
				}
			}

			// Sort item collections if a sort function was provided
			if (options?.sort) {
				for (const [k, items] of map.entries()) {
					map.set(k, [...items].sort(options.sort));
				}
			}

			return map;
		},
		on_add: (map, item) => {
			if (options?.matches && !options.matches(item)) return map;

			const keys = extractor(item);
			if (keys === undefined) return map;

			if (Array.isArray(keys)) {
				for (const k of keys) {
					if (k === undefined) continue;
					const collection = map.get(k) || [];
					collection.push(item);

					if (options?.sort) {
						collection.sort(options.sort);
					}

					map.set(k, collection);
				}
			} else {
				const collection = map.get(keys) || [];
				collection.push(item);

				if (options?.sort) {
					collection.sort(options.sort);
				}

				map.set(keys, collection);
			}
			return map;
		},
		on_remove: (map, item) => {
			if (options?.matches && !options.matches(item)) return map;

			const keys = extractor(item);
			if (keys === undefined) return map;

			if (Array.isArray(keys)) {
				for (const k of keys) {
					if (k === undefined) continue;
					const collection = map.get(k);
					if (collection) {
						const updated = collection.filter((i) => i.id !== item.id);
						if (updated.length === 0) {
							map.delete(k);
						} else {
							map.set(k, updated);
						}
					}
				}
			} else {
				const collection = map.get(keys);
				if (collection) {
					const updated = collection.filter((i) => i.id !== item.id);
					if (updated.length === 0) {
						map.delete(keys);
					} else {
						map.set(keys, updated);
					}
				}
			}
			return map;
		},
	};
}

/**
 * Options for derived indexes
 */
export interface Derived_Index_Options<T extends Indexed_Item, Q = void> extends Index_Options<T> {
	/** Schema for input validation and typing */
	query_schema?: z.ZodType<Q>;

	/** Optional sort function for the derived array */
	sort?: (a: T, b: T) => number;

	/** Optional custom add handler */
	on_add?: (items: Array<T>, item: T, collection: Indexed_Collection<T>) => Array<T>;

	/** Optional custom remove handler */
	on_remove?: (items: Array<T>, item: T, collection: Indexed_Collection<T>) => Array<T>;
}

/**
 * Create a derived collection index
 */
export function create_derived_index<T extends Indexed_Item, Q = void>(
	key: string,
	compute: (collection: Indexed_Collection<T>) => Array<T>,
	options?: Derived_Index_Options<T, Q>,
): Index_Definition<T, Array<T>, Q> {
	// Create the default output schema if not provided
	const result_schema =
		options?.result_schema ||
		z.array(z.custom<T>((val) => val && typeof val === 'object' && 'id' in val));

	return {
		key,
		type: 'derived',
		matches: options?.matches,
		query_schema: options?.query_schema,
		result_schema,
		compute: (collection) => {
			const result = compute(collection);
			if (options?.sort) {
				return [...result].sort(options.sort);
			}
			return result;
		},
		on_add: (items, item, collection) => {
			// Use custom handler if provided
			if (options?.on_add) {
				return options.on_add(items, item, collection);
			}

			// Default behavior: add item to the array if it matches, then sort if needed
			if (!options?.matches || options.matches(item)) {
				items.push(item);
				if (options?.sort) {
					items.sort(options.sort);
				}
			}
			return items;
		},
		on_remove: (items, item, collection) => {
			// Use custom handler if provided
			if (options?.on_remove) {
				return options.on_remove(items, item, collection);
			}

			// Default behavior: remove matching item by ID
			if (!options?.matches || options.matches(item)) {
				const index = items.findIndex((i) => i.id === item.id);
				if (index !== -1) {
					items.splice(index, 1);
				}
			}
			return items;
		},
	};
}

/**
 * Options for dynamic indexes
 */
export interface Dynamic_Index_Options<
	T extends Indexed_Item,
	F extends (...args: Array<any>) => any,
> {
	/** Optional predicate to determine when an item should trigger recalculation */
	matches?: (item: T) => boolean;

	/** Optional custom add handler - normally not needed for dynamic indexes */
	on_add?: (fn: F, item: T, collection: Indexed_Collection<T>) => F;

	/** Optional custom remove handler - normally not needed for dynamic indexes */
	on_remove?: (fn: F, item: T, collection: Indexed_Collection<T>) => F;
}

/**
 * Create a dynamic index that computes results on-demand based on query parameters
 *
 * Dynamic indexes return a function that can be called with parameters and will
 * return results from the current collection state. They're useful for creating
 * query-like interfaces without storing redundant data.
 */
export function create_dynamic_index<
	T extends Indexed_Item,
	F extends (...args: Array<any>) => any,
>(
	key: string,
	factory: (collection: Indexed_Collection<T>) => F,
	query_schema: z.ZodType<Parameters<F>[0]>,
	result_schema: z.ZodFunction<any, any>,
	options?: Dynamic_Index_Options<T, F>,
): Index_Definition<T, F, Parameters<F>[0]> {
	return {
		key,
		compute: factory,
		query_schema,
		result_schema: result_schema as any, // Casting due to Zod's complex types
		matches: options?.matches,
		// Dynamic indexes typically don't change as items are added/removed
		// since they compute their results on-demand from the current collection state
		on_add: options?.on_add || ((fn) => fn),
		on_remove: options?.on_remove || ((fn) => fn),
	};
}
