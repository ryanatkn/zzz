// @vitest-environment jsdom

import {test, expect, vi} from 'vitest';
import {z} from 'zod';

import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {
	create_multi_index,
	create_derived_index,
	create_dynamic_index,
} from '$lib/indexed_collection_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';

// Mock item type that implements Indexed_Item
interface Test_Item {
	id: Uuid;
	a: string;
	b: string;
	c: Array<string>;
	n: number;
}

// Helper function to create test items with predictable values
const create_item = (a: string, b: string, c: Array<string> = [], n: number = 0): Test_Item => ({
	id: Uuid.parse(undefined),
	a,
	b,
	c,
	n,
});

// Define test schemas
const item_schema = z.custom<Test_Item>((val) => val && typeof val === 'object' && 'id' in val);
const dynamic_function_schema = z.function().args(z.string()).returns(z.array(item_schema));

test('Indexed_Collection - optimization - indexes are computed only once during initialization', () => {
	// Create spy functions to count compute calls
	const compute_spy = vi.fn((collection) => {
		return new Map(collection.all.map((item: Test_Item) => [item.a, item]));
	});

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'test_index',
				compute: compute_spy,
				result_schema: z.map(z.string(), item_schema),
			},
		],
		initial_items: [create_item('a1', 'b1'), create_item('a2', 'b2')],
	});

	// Verify compute was called exactly once during initialization
	expect(compute_spy).toHaveBeenCalledTimes(1);
	expect(collection.size).toBe(2);
});

test('Indexed_Collection - optimization - incremental updates avoid recomputing entire index', () => {
	// Create spies for the compute and on_add functions
	const compute_spy = vi.fn((collection) => {
		return collection.all.filter((item: Test_Item) => item.n > 10);
	});

	const on_add_spy = vi.fn((items, item) => {
		if (item.n > 10) {
			items.push(item);
		}
		return items;
	});

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_derived_index({
				key: 'high_n',
				compute: compute_spy,
				matches: (item) => item.n > 10,
				on_add: on_add_spy,
			}),
		],
		initial_items: [create_item('a1', 'b1', [], 15), create_item('a2', 'b2', [], 5)],
	});

	// Verify compute was called exactly once during initialization
	expect(compute_spy).toHaveBeenCalledTimes(1);

	// Add more items and check that compute isn't called again
	collection.add(create_item('a3', 'b3', [], 20));
	collection.add(create_item('a4', 'b4', [], 8));

	// Compute should still have been called only once
	expect(compute_spy).toHaveBeenCalledTimes(1);

	// on_add should have been called twice - once for each new item
	expect(on_add_spy).toHaveBeenCalledTimes(2);

	// Check that the index was correctly updated
	const high_n = collection.get_derived('high_n');
	expect(high_n.length).toBe(2);
	expect(high_n.some((item) => item.a === 'a1')).toBe(true);
	expect(high_n.some((item) => item.a === 'a3')).toBe(true);
});

test('Indexed_Collection - optimization - batch operations are more efficient', () => {
	// Create a collection with a multi-index
	const on_add_spy = vi.fn((map, item) => {
		const collection = map.get(item.b) || [];
		collection.push(item);
		map.set(item.b, collection);
		return map;
	});

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'by_b',
				type: 'multi',
				extractor: (item) => item.b,
				compute: (collection) => {
					const map = new Map();
					for (const item of collection.all) {
						const collection = map.get(item.b) || [];
						collection.push(item);
						map.set(item.b, collection);
					}
					return map;
				},
				query_schema: z.string(),
				result_schema: z.map(z.string(), z.array(item_schema)),
				on_add: on_add_spy,
			},
		],
	});

	// Test batch add performance
	const start_time = performance.now();

	const items = Array.from({length: 100}, (_, i) =>
		create_item(`a${i}`, i % 5 === 0 ? 'b1' : 'b2'),
	);

	collection.add_many(items);

	const end_time = performance.now();
	const batch_time = end_time - start_time;

	// Verify on_add was called for each item
	expect(on_add_spy).toHaveBeenCalledTimes(100);

	// Reset the spy for individual adds
	on_add_spy.mockClear();

	// Test individual adds
	const individual_start = performance.now();

	const more_items = Array.from({length: 100}, (_, i) =>
		create_item(`a${i + 100}`, i % 5 === 0 ? 'b1' : 'b2'),
	);

	for (const item of more_items) {
		collection.add(item);
	}

	const individual_end = performance.now();
	const individual_time = individual_end - individual_start;

	// Verify on_add was called for each item
	expect(on_add_spy).toHaveBeenCalledTimes(100);

	// This test is somewhat approximative but helps validate the efficiency
	// We're not making a strict assertion on performance as it can vary between environments
	console.log(`Batch add: ${batch_time}ms, Individual adds: ${individual_time}ms`);
});

test('Indexed_Collection - optimization - dynamic indexes avoid redundant storage', () => {
	// Create a collection with a dynamic index that computes on-demand
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_dynamic_index<Test_Item, (min_n: string) => Array<Test_Item>>({
				key: 'by_min_n',
				factory: (collection) => {
					return (min_n: string) => {
						const threshold = parseInt(min_n, 10);
						return collection.all.filter((item) => item.n >= threshold);
					};
				},
				query_schema: z.string(),
				result_schema: dynamic_function_schema,
			}),
		],
	});

	// Add test data
	for (let i = 0; i < 20; i++) {
		collection.add(create_item(`a${i}`, `b${i % 3}`, [], i * 5));
	}

	// Verify function index produces different results based on input
	const n_fn = collection.get_index<(threshold: string) => Array<Test_Item>>('by_min_n');

	// These should return different filtered subsets without storing separate copies
	expect(n_fn('10').length).not.toBe(n_fn('50').length);
	expect(n_fn('0').length).toBe(20); // All items
	expect(n_fn('50').length).toBe(10); // Half the items
	expect(n_fn('90').length).toBe(2); // Just the highest values
});

test('Indexed_Collection - optimization - memory usage with large datasets', () => {
	// This test creates a large dataset and verifies indexes work efficiently
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	// Create a large dataset (~1000 items)
	const large_dataset = Array.from({length: 1000}, (_, i) =>
		create_item(`a${i}`, `b${i % 10}`, [`c${i % 20}`], i),
	);

	// Add them in one batch
	collection.add_many(large_dataset);

	// Create indexes after adding data
	collection.indexes.by_b = create_multi_index({
		key: 'by_b',
		extractor: (item: any) => item.b,
	}).compute(collection);

	// Verify the index contains the expected number of categories
	const b_index = collection.get_index<Map<string, Array<Test_Item>>>('by_b');
	expect(b_index.size).toBe(10); // 10 unique categories

	// Verify each category has the right number of items
	for (let i = 0; i < 10; i++) {
		expect(collection.where('by_b', `b${i}`).length).toBe(100); // 1000 items / 10 categories = 100 per category
	}
});
