import {SvelteMap} from 'svelte/reactivity';
import {z} from 'zod';
import type {
	Indexed_Item,
	Index_Definition,
	Indexed_Collection,
} from '$lib/indexed_collection.svelte.js';

/**
 * Create a single-value index (one key maps to one item)
 */
export function create_single_index<T extends Indexed_Item, K = any>(
	key: string,
	extractor: (item: T) => K,
	input_schema?: z.ZodType<K>,
): Index_Definition<T, SvelteMap<K, T>, K> {
	return {
		key,
		type: 'single',
		extractor,
		// Use provided input schema or create a generic one
		input_schema: input_schema || (z.any() as z.ZodType<K>),
		compute: (collection) => {
			const map: SvelteMap<K, T> = new SvelteMap();
			for (const item of collection.all) {
				const extract_key = extractor(item);
				if (extract_key !== undefined) {
					map.set(extract_key, item);
				}
			}
			return map;
		},
		// Define a schema that validates the result is a SvelteMap
		output_schema: z.custom<SvelteMap<K, T>>((val) => val instanceof SvelteMap),
		on_add: (map, item) => {
			const key = extractor(item);
			if (key !== undefined) {
				map.set(key, item);
			}
			return map;
		},
		on_remove: (map, item, collection) => {
			// We need to check if this item is still referenced by this key
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
 * Create a multi-value index (one key maps to many items)
 */
export function create_multi_index<T extends Indexed_Item, K = any>(
	key: string,
	extractor: (item: T) => K | Array<K>,
	input_schema?: z.ZodType<K>,
): Index_Definition<T, SvelteMap<K, Array<T>>, K> {
	return {
		key,
		type: 'multi',
		extractor,
		// Use provided input schema or create a generic one
		input_schema: input_schema || z.any(),
		compute: (collection) => {
			const map: SvelteMap<any, Array<T>> = new SvelteMap();
			for (const item of collection.all) {
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
			return map;
		},
		// Improved schema that includes information about the array type
		output_schema: z.custom<SvelteMap<K, Array<T>>>((val) => val instanceof SvelteMap),
		on_add: (map, item) => {
			const keys = extractor(item);
			if (keys === undefined) return map;

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
			return map;
		},
		on_remove: (map, item) => {
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
 * Create a derived collection index
 */
export function create_derived_index<T extends Indexed_Item, Q = void>(
	key: string,
	compute: (collection: Indexed_Collection<T>) => Array<T>,
	options?: {
		matches?: (item: T) => boolean;
		on_add?: (items: Array<T>, item: T, source: Indexed_Collection<T>) => Array<T>;
		on_remove?: (items: Array<T>, item: T, source: Indexed_Collection<T>) => Array<T>;
		// Add optional input schema parameter with explicit type
		input_schema?: z.ZodType<Q>;
	},
): Index_Definition<T, Array<T>, Q> {
	return {
		key,
		type: 'derived',
		compute,
		// Include input schema if provided in options
		input_schema: options?.input_schema,
		// Define a schema that validates the result is an array of the item type
		output_schema: z.array(
			z.custom<T>((val) => {
				// Basic check that it has an id property of type Uuid
				return val && typeof val === 'object' && 'id' in val;
			}),
		),
		matches: options?.matches,
		on_add: (items: Array<T>, item: T, collection: Indexed_Collection<T>) => {
			// If there's a custom update function, use it
			if (options?.on_add) {
				return options.on_add(items, item, collection);
			}

			// Default behavior: add item to end if it matches
			if (!options?.matches || options.matches(item)) {
				items.push(item);
			}
			return items;
		},
		on_remove: (items: Array<T>, item: T, collection: Indexed_Collection<T>) => {
			// If there's a custom update function, use it
			if (options?.on_remove) {
				return options.on_remove(items, item, collection);
			}

			// Default behavior: remove item by ID if it matches
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
