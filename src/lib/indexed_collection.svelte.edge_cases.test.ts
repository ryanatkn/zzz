// @slop claude_opus_4

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
import {create_uuid, Uuid} from '$lib/zod_helpers.js';

/* eslint-disable @typescript-eslint/no-empty-function */

// Mock item type that implements Indexed_Item
interface Test_Item {
	id: Uuid;
	string_a: string;
	number_a: number | null;
	array_a: Array<string>;
	boolean_a: boolean;
}

// Helper function to create test items with predictable values
const create_test_item = (
	string_a: string,
	number_a: number | null = 0,
	array_a: Array<string> = [],
	boolean_a = true,
): Test_Item => ({
	id: create_uuid(),
	string_a,
	number_a,
	array_a,
	boolean_a,
});

describe('Indexed_Collection - Edge Cases', () => {
	test('handling null/undefined values in index extractors', () => {
		// Create indexes that handle null/undefined values explicitly
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				// Single index that filters out null values
				create_single_index({
					key: 'by_number_a',
					extractor: (item) => item.number_a, // May return null
					query_schema: z.number().nullable(),
				}),

				// Multi-index that handles undefined values safely
				create_multi_index({
					key: 'by_array_a',
					extractor: (item) => (item.array_a.length > 0 ? item.array_a : undefined),
					query_schema: z.string(),
				}),
			],
		});

		// Add items with edge case values
		const item1 = create_test_item('a1', 5, ['tag1']);
		const item2 = create_test_item('a2', null, ['tag2']);
		const item3 = create_test_item('a3', 10, []); // Empty array
		const item4 = create_test_item('a4', 15, ['tag1', 'tag3']);

		collection.add_many([item1, item2, item3, item4]);

		// Test retrieving with null values
		expect(collection.by_optional('by_number_a', null)?.string_a).toBe('a2');

		// Test filtering with non-existing value
		expect(collection.by_optional('by_number_a', 999)).toBeUndefined();

		// Test multi-index with shared array values
		const tag1_items = collection.where('by_array_a', 'tag1');
		expect(tag1_items.length).toBe(2);
		expect(tag1_items.map((i) => i.string_a).sort()).toEqual(['a1', 'a4'].sort());

		// Item with empty array should be excluded from by_array_a index
		expect(collection.where('by_array_a', undefined)).toHaveLength(0);

		// Test removing an item with null value
		collection.remove(item2.id);
		expect(collection.by_optional('by_number_a', null)).toBeUndefined();

		// Add another item with null value
		const item5 = create_test_item('a5', null, ['tag5']);
		collection.add(item5);
		expect(collection.by_optional('by_number_a', null)?.string_a).toBe('a5');
	});

	test('handling duplicates in single indexes', () => {
		// Create a single index where multiple items might share the same key
		const console_warn_spy = vi.spyOn(console, 'warn').mockImplementation(() => {});

		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_prefix',
					extractor: (item) => item.string_a.substring(0, 1), // First char
					query_schema: z.string(),
				}),
				// Add explicit text index for easier item retrieval
				create_single_index({
					key: 'by_string_a',
					extractor: (item) => item.string_a,
					query_schema: z.string(),
				}),
			],
		});

		// Add items with duplicate prefixes
		const item1 = create_test_item('a123', 1);
		const item2 = create_test_item('a456', 2);
		const item3 = create_test_item('b789', 3);

		// Add them in a specific order
		collection.add(item1); // First 'a' item
		collection.add(item3); // Different prefix
		collection.add(item2); // Second 'a' item - should overwrite item1 in the index

		// Check that the latest addition wins for duplicate keys
		expect(collection.by_optional('by_prefix', 'a')?.string_a).toBe('a456');
		expect(collection.by_optional('by_prefix', 'b')?.string_a).toBe('b789');

		// Test what happens when removing an item that was overwritten in the index
		collection.remove(item2.id); // Remove the winning item

		// The index should now revert to the first item with the same key
		expect(collection.by_optional('by_prefix', 'a')?.string_a).toBe('a123');

		// Check that removing all items with the same key clears the index entry
		collection.remove(item1.id);
		expect(collection.by_optional('by_prefix', 'a')).toBeUndefined();

		console_warn_spy.mockRestore();
	});

	test('batch operations performance', {timeout: 10000}, () => {
		// Create a collection with multiple indexes to stress test performance
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_string_a',
					extractor: (item) => item.string_a,
					query_schema: z.string(),
				}),

				create_multi_index({
					key: 'by_array_a',
					extractor: (item) => item.array_a,
					query_schema: z.string(),
				}),

				create_derived_index({
					key: 'filtered_items',
					compute: (collection) => {
						const result = [];
						for (const item of collection.by_id.values()) {
							if (item.boolean_a && item.number_a !== null) {
								result.push(item);
							}
						}
						return result.sort((a, b) => (b.number_a || 0) - (a.number_a || 0));
					},
					matches: (item) => item.boolean_a && item.number_a !== null,
					sort: (a, b) => (b.number_a || 0) - (a.number_a || 0),
				}),
			],
		});

		// Create a smaller batch with varied properties
		const test_batch = Array.from({length: 100}, (_, i) => {
			const boolean_a = i % 3 === 0;
			const number_a = i % 5 === 0 ? null : i;
			const array_a = [`tag${i % 10}`, `category${i % 5}`];
			return create_test_item(`item${i}`, number_a, array_a, boolean_a);
		});

		// Measure time to add all items
		const start_time = performance.now();
		collection.add_many(test_batch);
		const end_time = performance.now();

		// Just log the time, don't make strict assertions as performance varies by environment
		console.log(`Time to add 100 items with 3 indexes: ${end_time - start_time}ms`);

		// Verify all indexes were created correctly
		expect(collection.size).toBe(100);
		expect(Object.keys(collection.indexes).length).toBe(3);

		// Test various queries against the indexes
		expect(collection.by_optional('by_string_a', 'item23')?.number_a).toBe(23);
		expect(collection.where('by_array_a', 'tag5').length).toBe(10); // 10% of items have tag5
		expect(collection.derived_index('filtered_items').length).toBe(
			test_batch.filter((i) => i.boolean_a && i.number_a !== null).length,
		);

		// Test removing half of the items
		const to_remove = test_batch.slice(0, 50).map((item) => item.id);
		const remove_start = performance.now();
		collection.remove_many(to_remove);
		const remove_end = performance.now();

		console.log(`Time to remove 50 items: ${remove_end - remove_start}ms`);
		expect(collection.size).toBe(50);
	});

	test('error handling for invalid index type access', () => {
		// Create a collection with mix of index types
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_string_a',
					extractor: (item) => item.string_a,
					query_schema: z.string(),
				}),
				create_multi_index({
					key: 'by_array_a',
					extractor: (item) => item.array_a,
					query_schema: z.string(),
				}),
			],
		});

		// Add a test item
		collection.add(create_test_item('a1', 1, ['tag1']));

		// Test accessing indexes with wrong methods
		expect(() => {
			collection.where('by_string_a', 'a1'); // Using multi-index method on single index
		}).toThrow(); // Should throw error about index type mismatch

		expect(() => {
			collection.by<string>('by_array_a', 'tag1'); // Using single-index method on multi-index
		}).toThrow(); // Should throw error about index type mismatch
	});

	test('handling invalid queries with schema validation', () => {
		// Create a collection with strict schema validation
		const console_error_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_number_a',
					extractor: (item) => item.number_a,
					query_schema: z.number().positive(), // Must be positive number
				}),
			],
			validate: true, // Enable validation
		});

		// Add test items
		collection.add(create_test_item('a1', 5));
		collection.add(create_test_item('a2', -1)); // Negative value
		collection.add(create_test_item('a3', null)); // Null value

		// Test valid query
		expect(collection.by_optional('by_number_a', 5)?.string_a).toBe('a1');

		// Test queries that violate schema
		collection.query('by_number_a', -10); // Negative number, should log validation error
		expect(console_error_spy).toHaveBeenCalled();

		console_error_spy.mockClear();
		collection.query('by_number_a', null); // Null, should log validation error
		expect(console_error_spy).toHaveBeenCalled();

		console_error_spy.mockRestore();
	});

	test('dynamic indexes with custom handlers', () => {
		// Test a dynamic index with custom add/remove handlers
		const compute_fn = vi.fn();
		const onadd_fn = vi.fn((_fn, item, collection) => {
			// Return a new function that references the added item
			return (query: string) => {
				compute_fn(query);
				if (query === item.string_a) {
					return [item];
				}

				const result = [];
				for (const i of collection.by_id.values()) {
					if (i.string_a.includes(query)) {
						result.push(i);
					}
				}
				return result;
			};
		});

		const onremove_fn = vi.fn((_fn, _item, collection) => {
			// Return a new function that excludes the removed item
			return (query: string) => {
				compute_fn(query);

				const result = [];
				for (const i of collection.by_id.values()) {
					if (i.string_a.includes(query)) {
						result.push(i);
					}
				}
				return result;
			};
		});

		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_dynamic_index<Test_Item, (query: string) => Array<Test_Item>>({
					key: 'search',
					factory: (collection) => {
						return (query: string) => {
							compute_fn(query);

							const result = [];
							for (const i of collection.by_id.values()) {
								if (i.string_a.includes(query)) {
									result.push(i);
								}
							}
							return result;
						};
					},
					query_schema: z.string(),
					onadd: onadd_fn,
					onremove: onremove_fn,
				}),
			],
		});

		// Add test items and verify custom handlers
		const item1 = create_test_item('x1');
		collection.add(item1);
		expect(onadd_fn).toHaveBeenCalled();

		const item2 = create_test_item('y2');
		collection.add(item2);

		// Test the search index
		const search_fn = collection.get_index<(q: string) => Array<Test_Item>>('search');

		// Search functions should work
		const x_results = search_fn('x');
		expect(x_results.length).toBe(1);
		expect(x_results[0].string_a).toBe('x1');
		expect(compute_fn).toHaveBeenLastCalledWith('x');

		// Test removing an item triggers onremove
		collection.remove(item1.id);
		expect(onremove_fn).toHaveBeenCalled();

		// Search function should be updated
		const no_results = search_fn('x');
		expect(no_results.length).toBe(0);
	});

	test('custom complex index behaviors', () => {
		// Create a collection with a custom index that has advanced logic
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				// Add explicit string_a index for lookup
				create_single_index({
					key: 'by_string_a',
					extractor: (item) => item.string_a,
					query_schema: z.string(),
				}),
				// Custom index that maintains an aggregated stats object
				{
					key: 'stats',
					compute: (collection) => {
						const items = [...collection.by_id.values()];
						return {
							count: items.length,
							boolean_a_true_count: items.filter((i) => i.boolean_a).length,
							boolean_a_false_count: items.filter((i) => !i.boolean_a).length,
							sum_number_a: items.reduce((sum, i) => sum + (i.number_a || 0), 0),
							array_a_frequency: items.reduce<Record<string, number>>((freq, item) => {
								for (const value of item.array_a) {
									freq[value] = (freq[value] || 0) + 1;
								}
								return freq;
							}, {}),
						};
					},
					onadd: (stats: any, item: Test_Item) => {
						stats.count++;
						if (item.boolean_a) stats.boolean_a_true_count++;
						else stats.boolean_a_false_count++;
						stats.sum_number_a += item.number_a || 0;

						// Update array_a frequencies
						for (const value of item.array_a) {
							stats.array_a_frequency[value] = (stats.array_a_frequency[value] || 0) + 1;
						}

						return stats;
					},
					onremove: (stats: any, item: Test_Item) => {
						stats.count--;
						if (item.boolean_a) stats.boolean_a_true_count--;
						else stats.boolean_a_false_count--;
						stats.sum_number_a -= item.number_a || 0;

						// Update array_a frequencies
						for (const value of item.array_a) {
							stats.array_a_frequency[value]--;
							if (stats.array_a_frequency[value] === 0) {
								delete stats.array_a_frequency[value]; // eslint-disable-line @typescript-eslint/no-dynamic-delete
							}
						}
						return stats;
					},
					result_schema: z.object({
						count: z.number(),
						boolean_a_true_count: z.number(),
						boolean_a_false_count: z.number(),
						sum_number_a: z.number(),
						array_a_frequency: z.record(z.string(), z.number()),
					}),
				},
			],
		});

		// Add items to test stats tracking
		const item1 = create_test_item('a1', 10, ['tag1', 'tag2'], true);
		const item2 = create_test_item('a2', 20, ['tag2', 'tag3'], false);
		const item3 = create_test_item('a3', 30, ['tag1', 'tag3'], true);

		collection.add(item1);
		collection.add(item2);
		collection.add(item3);

		// Check that stats were computed correctly
		const stats = collection.get_index<{
			count: number;
			boolean_a_true_count: number;
			boolean_a_false_count: number;
			sum_number_a: number;
			array_a_frequency: Record<string, number>;
		}>('stats');

		expect(stats.count).toBe(3);
		expect(stats.boolean_a_true_count).toBe(2);
		expect(stats.boolean_a_false_count).toBe(1);
		expect(stats.sum_number_a).toBe(60);
		expect(stats.array_a_frequency).toEqual({
			tag1: 2,
			tag2: 2,
			tag3: 2,
		});

		// Test incremental update - add an item
		collection.add(create_test_item('a4', 40, ['tag1', 'tag4'], false));

		expect(stats.count).toBe(4);
		expect(stats.boolean_a_true_count).toBe(2);
		expect(stats.boolean_a_false_count).toBe(2);
		expect(stats.sum_number_a).toBe(100);
		expect(stats.array_a_frequency.tag1).toBe(3);
		expect(stats.array_a_frequency.tag4).toBe(1);

		// Test incremental update - remove an item
		// Store the item reference first to ensure it exists
		const item1_ref = collection.by_optional('by_string_a', 'a1');
		expect(item1_ref).toBeDefined(); // Make sure we found it
		collection.remove(item1_ref!.id);

		expect(stats.count).toBe(3);
		expect(stats.boolean_a_true_count).toBe(1);
		expect(stats.boolean_a_false_count).toBe(2);
		expect(stats.sum_number_a).toBe(90);
		expect(stats.array_a_frequency.tag1).toBe(2);
		expect(stats.array_a_frequency.tag2).toBe(1);
	});
});
