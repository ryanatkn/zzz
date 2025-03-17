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
	a: string;
	b: number | null;
	c: Array<string>;
	d: boolean;
}

// Helper function to create test items
const create_edge_item = (
	a: string,
	b: number | null = 0,
	c: Array<string> = [],
	d = true,
): Edge_Test_Item => ({
	id: Uuid.parse(undefined),
	a,
	b,
	c,
	d,
});

describe('Indexed_Collection - Edge Cases', () => {
	test('handling null/undefined values in index extractors', () => {
		// Create indexes that handle null/undefined values explicitly
		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				// Single index that filters out null values
				create_single_index({
					key: 'by_b',
					extractor: (item) => item.b, // May return null
					query_schema: z.number().nullable(),
				}),

				// Multi-index that handles undefined values safely
				create_multi_index({
					key: 'by_c',
					extractor: (item) => (item.c.length > 0 ? item.c : undefined),
					query_schema: z.string(),
				}),
			],
		});

		// Add items with edge case values
		const item1 = create_edge_item('a1', 5, ['c1']);
		const item2 = create_edge_item('a2', null, ['c2']);
		const item3 = create_edge_item('a3', 10, []); // No c values
		const item4 = create_edge_item('a4', 15, ['c1', 'c3']);

		collection.add_many([item1, item2, item3, item4]);

		// Test retrieving with null values
		expect(collection.by_optional('by_b', null)?.a).toBe('a2');

		// Test filtering with null values
		expect(collection.by_optional('by_b', 999)).toBeUndefined(); // Non-existing value

		// Test multi-index with shared c values
		const c1_items = collection.where('by_c', 'c1');
		expect(c1_items.length).toBe(2);
		expect(c1_items.map((i) => i.a).sort()).toEqual(['a1', 'a4'].sort());

		// Item with empty c array should be excluded from by_c index
		expect(collection.where('by_c', undefined)).toHaveLength(0);

		// Test removing an item with null value
		collection.remove(item2.id);
		expect(collection.by_optional('by_b', null)).toBeUndefined();

		// Add another item with null value
		const item5 = create_edge_item('a5', null, ['c5']);
		collection.add(item5);
		expect(collection.by_optional('by_b', null)?.a).toBe('a5');
	});

	test('handling duplicates in single indexes', () => {
		// Create a single index where multiple items might share the same key
		const console_warn_spy = vi.spyOn(console, 'warn').mockImplementation(() => {});

		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_truncated_a',
					extractor: (item) => item.a.substring(0, 3), // First 3 chars
					query_schema: z.string(),
				}),
				// Add explicit a index for easier item retrieval
				create_single_index({
					key: 'by_a',
					extractor: (item) => item.a,
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
		expect(collection.by_optional('by_truncated_a', 'abc')?.a).toBe('abc456');
		expect(collection.by_optional('by_truncated_a', 'def')?.a).toBe('def789');

		// Test what happens when removing an item that was overwritten in the index
		collection.remove(item2.id); // Remove the winning item

		// The index should now revert to the first item with the same key
		expect(collection.by_optional('by_truncated_a', 'abc')?.a).toBe('abc123');

		// Check that removing all items with the same key clears the index entry
		const key1 = item1.id; // Store the ID before removing to avoid test failure
		collection.remove(key1);
		expect(collection.by_optional('by_truncated_a', 'abc')).toBeUndefined();

		console_warn_spy.mockRestore();
	});

	test('batch operations performance', {timeout: 10000}, () => {
		// Create a collection with multiple indexes to stress test performance
		// But use fewer items to prevent test timeouts
		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_a',
					extractor: (item) => item.a,
					query_schema: z.string(),
				}),

				create_multi_index({
					key: 'by_c',
					extractor: (item) => item.c,
					query_schema: z.string(),
				}),

				create_derived_index({
					key: 'd_by_b',
					compute: (collection) => {
						return collection.all
							.filter((item) => item.d && item.b !== null)
							.sort((a, b) => (b.b || 0) - (a.b || 0));
					},
					matches: (item) => item.d && item.b !== null,
					sort: (a, b) => (b.b || 0) - (a.b || 0),
				}),
			],
		});

		// Create a smaller batch (100 items) with varied properties
		const large_batch = Array.from({length: 100}, (_, i) => {
			const d = i % 3 === 0;
			const b = i % 5 === 0 ? null : i;
			const c = [`c${i % 10}`, `g${i % 5}`];
			return create_edge_item(`a${i}`, b, c, d);
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
		expect(collection.by_optional('by_a', 'a23')?.b).toBe(23);
		expect(collection.where('by_c', 'c5').length).toBe(10); // 10% of items have c5
		expect(collection.get_derived('d_by_b').length).toBe(
			large_batch.filter((i) => i.d && i.b !== null).length,
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
					key: 'by_a',
					extractor: (item) => item.a,
					query_schema: z.string(),
				}),
				create_multi_index({
					key: 'by_c',
					extractor: (item) => item.c,
					query_schema: z.string(),
				}),
			],
		});

		// Add a test item
		collection.add(create_edge_item('a1', 1, ['c1']));

		// Test accessing indexes with wrong methods
		expect(() => {
			collection.where('by_a', 'a1'); // Using multi-index method on single index
		}).toThrow(); // Should throw error about index type mismatch

		expect(() => {
			collection.by<string>('by_c', 'c1'); // Using single-index method on multi-index
		}).toThrow(); // Should throw error about index type mismatch
	});

	test('handling invalid queries with schema validation', () => {
		// Create a collection with strict schema validation
		const console_error_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_b',
					extractor: (item) => item.b,
					query_schema: z.number().positive(), // Must be positive number
				}),
			],
			validate: true, // Enable validation
		});

		// Add test items
		collection.add(create_edge_item('a1', 5));
		collection.add(create_edge_item('a2', -1)); // Negative value
		collection.add(create_edge_item('a3', null)); // Null value

		// Test valid query
		expect(collection.by_optional('by_b', 5)?.a).toBe('a1');

		// Test queries that violate schema
		collection.query('by_b', -10); // Negative number, should log validation error
		expect(console_error_spy).toHaveBeenCalled();

		console_error_spy.mockClear();
		collection.query('by_b', null); // Null, should log validation error
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
				if (query === item.a) {
					return [item];
				}
				return collection.all.filter((i: any) => i.a.includes(query));
			};
		});

		const on_remove_fn = vi.fn((_fn, _item, collection) => {
			// Return a new function that excludes the removed item
			return (query: string) => {
				compute_fn(query);
				return collection.all.filter((i: any) => i.a.includes(query));
			};
		});

		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				create_dynamic_index<Edge_Test_Item, (query: string) => Array<Edge_Test_Item>>({
					key: 'search',
					factory: (collection) => {
						return (query: string) => {
							compute_fn(query);
							return collection.all.filter((i) => i.a.includes(query));
						};
					},
					query_schema: z.string(),
					on_add: on_add_fn,
					on_remove: on_remove_fn,
				}),
			],
		});

		// Add test items and verify custom handlers
		const item1 = create_edge_item('x1');
		collection.add(item1);
		expect(on_add_fn).toHaveBeenCalled();

		const item2 = create_edge_item('y2');
		collection.add(item2);

		// Test the search index
		const search_fn = collection.get_index<(q: string) => Array<Edge_Test_Item>>('search');

		// Search functions should work
		const x_results = search_fn('x');
		expect(x_results.length).toBe(1);
		expect(x_results[0].a).toBe('x1');
		expect(compute_fn).toHaveBeenLastCalledWith('x');

		// Test removing an item triggers on_remove
		collection.remove(item1.id);
		expect(on_remove_fn).toHaveBeenCalled();

		// Search function should be updated
		const no_results = search_fn('x');
		expect(no_results.length).toBe(0);
	});

	test('custom complex index behaviors', () => {
		// Create a collection with a custom index that has advanced logic
		const collection: Indexed_Collection<Edge_Test_Item> = new Indexed_Collection({
			indexes: [
				// Add explicit a index for lookup
				create_single_index({
					key: 'by_a',
					extractor: (item) => item.a,
					query_schema: z.string(),
				}),
				// Custom index that maintains an aggregated stats object
				{
					key: 'stats',
					compute: (collection) => {
						return {
							count: collection.all.length,
							d_true_count: collection.all.filter((i) => i.d).length,
							d_false_count: collection.all.filter((i) => !i.d).length,
							sum_b: collection.all.reduce((sum, i) => sum + (i.b || 0), 0),
							c_frequency: collection.all.reduce<Record<string, number>>((freq, item) => {
								for (const value of item.c) {
									freq[value] = (freq[value] || 0) + 1;
								}
								return freq;
							}, {}),
						};
					},
					on_add: (stats: any, item: Edge_Test_Item) => {
						stats.count++;
						if (item.d) stats.d_true_count++;
						else stats.d_false_count++;
						stats.sum_b += item.b || 0;

						// Update c frequencies
						for (const value of item.c) {
							stats.c_frequency[value] = (stats.c_frequency[value] || 0) + 1;
						}

						return stats;
					},
					on_remove: (stats: any, item: Edge_Test_Item) => {
						stats.count--;
						if (item.d) stats.d_true_count--;
						else stats.d_false_count--;
						stats.sum_b -= item.b || 0;

						// Update c frequencies
						for (const value of item.c) {
							stats.c_frequency[value]--;
							if (stats.c_frequency[value] === 0) {
								delete stats.c_frequency[value]; // eslint-disable-line @typescript-eslint/no-dynamic-delete
							}
						}
						return stats;
					},
					result_schema: z.object({
						count: z.number(),
						d_true_count: z.number(),
						d_false_count: z.number(),
						sum_b: z.number(),
						c_frequency: z.record(z.string(), z.number()),
					}),
				},
			],
		});

		// Add items to test stats tracking
		const item1 = create_edge_item('a1', 10, ['c1', 'c2'], true);
		const item2 = create_edge_item('a2', 20, ['c2', 'c3'], false);
		const item3 = create_edge_item('a3', 30, ['c1', 'c3'], true);

		collection.add(item1);
		collection.add(item2);
		collection.add(item3);

		// Check that stats were computed correctly
		const stats = collection.get_index<{
			count: number;
			d_true_count: number;
			d_false_count: number;
			sum_b: number;
			c_frequency: Record<string, number>;
		}>('stats');

		expect(stats.count).toBe(3);
		expect(stats.d_true_count).toBe(2);
		expect(stats.d_false_count).toBe(1);
		expect(stats.sum_b).toBe(60);
		expect(stats.c_frequency).toEqual({
			c1: 2,
			c2: 2,
			c3: 2,
		});

		// Test incremental update - add an item
		collection.add(create_edge_item('a4', 40, ['c1', 'c4'], false));

		expect(stats.count).toBe(4);
		expect(stats.d_true_count).toBe(2);
		expect(stats.d_false_count).toBe(2);
		expect(stats.sum_b).toBe(100);
		expect(stats.c_frequency.c1).toBe(3);
		expect(stats.c_frequency.c4).toBe(1);

		// Test incremental update - remove an item
		// Store the item reference first to ensure it exists
		const item1_ref = collection.by_optional('by_a', 'a1');
		expect(item1_ref).toBeDefined(); // Make sure we found it
		collection.remove(item1_ref!.id);

		expect(stats.count).toBe(3);
		expect(stats.d_true_count).toBe(1);
		expect(stats.d_false_count).toBe(2);
		expect(stats.sum_b).toBe(90);
		expect(stats.c_frequency.c1).toBe(2);
		expect(stats.c_frequency.c2).toBe(1);
	});
});
