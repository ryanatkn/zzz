// @vitest-environment jsdom

import {test, expect, describe, vi} from 'vitest';
import {z} from 'zod';

import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {
	create_single_index,
	create_multi_index,
	create_derived_index,
	create_dynamic_index,
} from '$lib/indexed_collection_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';

/* eslint-disable @typescript-eslint/no-empty-function */

// Basic test item type
interface Edge_Test_Item {
	id: Uuid;
	name: string;
	value: number | null;
	tags: Array<string>;
	active: boolean;
}

// Helper function to create test items
const create_edge_item = (
	name: string,
	value: number | null = 0,
	tags: Array<string> = [],
	active = true,
): Edge_Test_Item => ({
	id: Uuid.parse(undefined),
	name,
	value,
	tags,
	active,
});

describe('Indexed_Collection - Edge Cases', () => {
	test('handling null/undefined values in index extractors', () => {
		// Create indexes that handle null/undefined values explicitly
		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				// Single index that filters out null values
				create_single_index({
					key: 'by_value',
					extractor: (item) => item.value, // May return null
					query_schema: z.number().nullable(),
				}),

				// Multi-index that handles undefined values safely
				create_multi_index({
					key: 'by_tag',
					extractor: (item) => (item.tags.length > 0 ? item.tags : undefined),
					query_schema: z.string(),
				}),
			],
		});

		// Add items with edge case values
		const item1 = create_edge_item('item1', 5, ['tag1']);
		const item2 = create_edge_item('item2', null, ['tag2']);
		const item3 = create_edge_item('item3', 10, []); // No tags
		const item4 = create_edge_item('item4', 15, ['tag1', 'tag3']);

		collection.add_many([item1, item2, item3, item4]);

		// Test retrieving with null values
		expect(collection.by_optional('by_value', null)?.name).toBe('item2');

		// Test filtering with null values
		expect(collection.by_optional('by_value', 999)).toBeUndefined(); // Non-existing value

		// Test multi-index with shared tags
		const tag1_items = collection.where('by_tag', 'tag1');
		expect(tag1_items.length).toBe(2);
		expect(tag1_items.map((i) => i.name).sort()).toEqual(['item1', 'item4'].sort());

		// Item with empty tags array should be excluded from by_tag index
		expect(collection.where('by_tag', undefined)).toHaveLength(0);

		// Test removing an item with null value
		collection.remove(item2.id);
		expect(collection.by_optional('by_value', null)).toBeUndefined();

		// Add another item with null value
		const item5 = create_edge_item('item5', null, ['tag5']);
		collection.add(item5);
		expect(collection.by_optional('by_value', null)?.name).toBe('item5');
	});

	test('handling duplicates in single indexes', () => {
		// Create a single index where multiple items might share the same key
		const console_warn_spy = vi.spyOn(console, 'warn').mockImplementation(() => {});

		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_truncated_name',
					extractor: (item) => item.name.substring(0, 3), // First 3 chars
					query_schema: z.string(),
				}),
				// Add explicit name index for easier item retrieval
				create_single_index({
					key: 'by_name',
					extractor: (item) => item.name,
					query_schema: z.string(),
				}),
			],
		});

		// Add items with duplicate truncated names
		const item1 = create_edge_item('abc123', 1);
		const item2 = create_edge_item('abc456', 2);
		const item3 = create_edge_item('def789', 3);

		// Add them in a specific order
		collection.add(item1); // First 'abc' item
		collection.add(item3); // Different prefix
		collection.add(item2); // Second 'abc' item - should overwrite item1 in the index

		// Check that the latest addition wins for duplicate keys
		expect(collection.by_optional('by_truncated_name', 'abc')?.name).toBe('abc456');
		expect(collection.by_optional('by_truncated_name', 'def')?.name).toBe('def789');

		// Test what happens when removing an item that was overwritten in the index
		collection.remove(item2.id); // Remove the winning item

		// The index should now revert to the first item with the same key
		expect(collection.by_optional('by_truncated_name', 'abc')?.name).toBe('abc123');

		// Check that removing all items with the same key clears the index entry
		const key1 = item1.id; // Store the ID before removing to avoid test failure
		collection.remove(key1);
		expect(collection.by_optional('by_truncated_name', 'abc')).toBeUndefined();

		console_warn_spy.mockRestore();
	});

	test('batch operations performance', {timeout: 10000}, () => {
		// Create a collection with multiple indexes to stress test performance
		// But use fewer items to prevent test timeouts
		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_name',
					extractor: (item) => item.name,
					query_schema: z.string(),
				}),

				create_multi_index({
					key: 'by_tag',
					extractor: (item) => item.tags,
					query_schema: z.string(),
				}),

				create_derived_index({
					key: 'active_by_value',
					compute: (collection) => {
						return collection.all
							.filter((item) => item.active && item.value !== null)
							.sort((a, b) => (b.value || 0) - (a.value || 0));
					},
					matches: (item) => item.active && item.value !== null,
					sort: (a, b) => (b.value || 0) - (a.value || 0),
				}),
			],
		});

		// Create a smaller batch (100 items) with varied properties
		const large_batch = Array.from({length: 100}, (_, i) => {
			const active = i % 3 === 0;
			const value = i % 5 === 0 ? null : i;
			const tags = [`tag${i % 10}`, `group${i % 5}`];
			return create_edge_item(`item${i}`, value, tags, active);
		});

		// Measure time to add all items
		const start_time = performance.now();
		collection.add_many(large_batch);
		const end_time = performance.now();

		// Just log the time, don't make strict assertions as performance varies by environment
		console.log(`Time to add 100 items with 3 indexes: ${end_time - start_time}ms`);

		// Verify all indexes were created correctly
		expect(collection.size).toBe(100);
		expect(Object.keys(collection.indexes).length).toBe(3);

		// Test various queries against the indexes
		expect(collection.by_optional('by_name', 'item23')?.value).toBe(23);
		expect(collection.where('by_tag', 'tag5').length).toBe(10); // 10% of items have tag5
		expect(collection.get_derived('active_by_value').length).toBe(
			large_batch.filter((i) => i.active && i.value !== null).length,
		);

		// Test removing half of the items
		const to_remove = large_batch.slice(0, 50).map((item) => item.id);
		const remove_start = performance.now();
		collection.remove_many(to_remove);
		const remove_end = performance.now();

		console.log(`Time to remove 50 items: ${remove_end - remove_start}ms`);
		expect(collection.size).toBe(50);
	});

	test('error handling for invalid index type access', () => {
		// Create a collection with mix of index types
		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_name',
					extractor: (item) => item.name,
					query_schema: z.string(),
				}),
				create_multi_index({
					key: 'by_tag',
					extractor: (item) => item.tags,
					query_schema: z.string(),
				}),
			],
		});

		// Add a test item
		collection.add(create_edge_item('test1', 1, ['tag1']));

		// Test accessing indexes with wrong methods
		expect(() => {
			collection.where('by_name', 'test1'); // Using multi-index method on single index
		}).toThrow(); // Should throw error about index type mismatch

		expect(() => {
			collection.by<string>('by_tag', 'tag1'); // Using single-index method on multi-index
		}).toThrow(); // Should throw error about index type mismatch
	});

	test('handling invalid queries with schema validation', () => {
		// Create a collection with strict schema validation
		const console_error_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_value',
					extractor: (item) => item.value,
					query_schema: z.number().positive(), // Must be positive number
				}),
			],
			validate: true, // Enable validation
		});

		// Add test items
		collection.add(create_edge_item('test1', 5));
		collection.add(create_edge_item('test2', -1)); // Negative value
		collection.add(create_edge_item('test3', null)); // Null value

		// Test valid query
		expect(collection.by_optional('by_value', 5)?.name).toBe('test1');

		// Test queries that violate schema
		collection.query('by_value', -10); // Negative number, should log validation error
		expect(console_error_spy).toHaveBeenCalled();

		console_error_spy.mockClear();
		collection.query('by_value', null); // Null, should log validation error
		expect(console_error_spy).toHaveBeenCalled();

		console_error_spy.mockRestore();
	});

	test('dynamic indexes with custom handlers', () => {
		// Test a dynamic index with custom add/remove handlers
		const compute_fn = vi.fn();
		const on_add_fn = vi.fn((_fn, item, collection) => {
			// Return a new function that references the added item
			return (query: string) => {
				compute_fn(query);
				if (query === item.name) {
					return [item];
				}
				return collection.all.filter((i: any) => i.name.includes(query));
			};
		});

		const on_remove_fn = vi.fn((_fn, _item, collection) => {
			// Return a new function that excludes the removed item
			return (query: string) => {
				compute_fn(query);
				return collection.all.filter((i: any) => i.name.includes(query));
			};
		});

		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				create_dynamic_index<Edge_Test_Item, (query: string) => Array<Edge_Test_Item>>({
					key: 'search',
					factory: (collection) => {
						return (query: string) => {
							compute_fn(query);
							return collection.all.filter((i) => i.name.includes(query));
						};
					},
					query_schema: z.string(),
					on_add: on_add_fn,
					on_remove: on_remove_fn,
				}),
			],
		});

		// Add test items and verify custom handlers
		const item1 = create_edge_item('apple');
		collection.add(item1);
		expect(on_add_fn).toHaveBeenCalled();

		const item2 = create_edge_item('banana');
		collection.add(item2);

		// Test the search index
		const search_fn = collection.get_index<(q: string) => Array<Edge_Test_Item>>('search');

		// Search functions should work
		const apple_results = search_fn('app');
		expect(apple_results.length).toBe(1);
		expect(apple_results[0].name).toBe('apple');
		expect(compute_fn).toHaveBeenLastCalledWith('app');

		// Test removing an item triggers on_remove
		collection.remove(item1.id);
		expect(on_remove_fn).toHaveBeenCalled();

		// Search function should be updated
		const no_results = search_fn('app');
		expect(no_results.length).toBe(0);
	});

	test('custom complex index behaviors', () => {
		// Create a collection with a custom index that has advanced logic
		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				// Add explicit name index for lookup
				create_single_index({
					key: 'by_name',
					extractor: (item) => item.name,
					query_schema: z.string(),
				}),
				// Custom index that maintains an aggregated stats object
				{
					key: 'stats',
					compute: (collection) => {
						return {
							total_items: collection.all.length,
							active_count: collection.all.filter((i) => i.active).length,
							inactive_count: collection.all.filter((i) => !i.active).length,
							total_value: collection.all.reduce((sum, i) => sum + (i.value || 0), 0),
							tags_frequency: collection.all.reduce<Record<string, number>>((freq, item) => {
								for (const tag of item.tags) {
									freq[tag] = (freq[tag] || 0) + 1;
								}
								return freq;
							}, {}),
						};
					},
					on_add: (stats: any, item: Edge_Test_Item) => {
						stats.total_items++;
						if (item.active) stats.active_count++;
						else stats.inactive_count++;
						stats.total_value += item.value || 0;

						// Update tag frequencies
						for (const tag of item.tags) {
							stats.tags_frequency[tag] = (stats.tags_frequency[tag] || 0) + 1;
						}

						return stats;
					},
					on_remove: (stats: any, item: Edge_Test_Item) => {
						stats.total_items--;
						if (item.active) stats.active_count--;
						else stats.inactive_count--;
						stats.total_value -= item.value || 0;

						// Update tag frequencies
						for (const tag of item.tags) {
							stats.tags_frequency[tag]--;
							if (stats.tags_frequency[tag] === 0) {
								delete stats.tags_frequency[tag]; // eslint-disable-line @typescript-eslint/no-dynamic-delete
							}
						}
						return stats;
					},
					result_schema: z.object({
						total_items: z.number(),
						active_count: z.number(),
						inactive_count: z.number(),
						total_value: z.number(),
						tags_frequency: z.record(z.string(), z.number()),
					}),
				},
			],
		});

		// Add items to test stats tracking
		const item1 = create_edge_item('item1', 10, ['tag1', 'tag2'], true);
		const item2 = create_edge_item('item2', 20, ['tag2', 'tag3'], false);
		const item3 = create_edge_item('item3', 30, ['tag1', 'tag3'], true);

		collection.add(item1);
		collection.add(item2);
		collection.add(item3);

		// Check that stats were computed correctly
		const stats = collection.get_index<{
			total_items: number;
			active_count: number;
			inactive_count: number;
			total_value: number;
			tags_frequency: Record<string, number>;
		}>('stats');

		expect(stats.total_items).toBe(3);
		expect(stats.active_count).toBe(2);
		expect(stats.inactive_count).toBe(1);
		expect(stats.total_value).toBe(60);
		expect(stats.tags_frequency).toEqual({
			tag1: 2,
			tag2: 2,
			tag3: 2,
		});

		// Test incremental update - add an item
		collection.add(create_edge_item('item4', 40, ['tag1', 'tag4'], false));

		expect(stats.total_items).toBe(4);
		expect(stats.active_count).toBe(2);
		expect(stats.inactive_count).toBe(2);
		expect(stats.total_value).toBe(100);
		expect(stats.tags_frequency.tag1).toBe(3);
		expect(stats.tags_frequency.tag4).toBe(1);

		// Test incremental update - remove an item
		// Store the item reference first to ensure it exists
		const item1_ref = collection.by_optional('by_name', 'item1');
		expect(item1_ref).toBeDefined(); // Make sure we found it
		collection.remove(item1_ref!.id);

		expect(stats.total_items).toBe(3);
		expect(stats.active_count).toBe(1);
		expect(stats.inactive_count).toBe(2);
		expect(stats.total_value).toBe(90);
		expect(stats.tags_frequency.tag1).toBe(2);
		expect(stats.tags_frequency.tag2).toBe(1);
	});
});
