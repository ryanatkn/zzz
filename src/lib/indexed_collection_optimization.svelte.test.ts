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
	name: string;
	category: string;
	things: Array<string>;
	value: number;
}

// Helper function to create test items with predictable values
const create_test_item = (
	name: string,
	category: string,
	things: Array<string> = [],
	value: number = 0,
): Test_Item => ({
	id: Uuid.parse(undefined),
	name,
	category,
	things,
	value,
});

// Define test schemas
const item_schema = z.custom<Test_Item>((val) => val && typeof val === 'object' && 'id' in val);
const dynamic_function_schema = z.function().args(z.string()).returns(z.array(item_schema));

test('Indexed_Collection - optimization - indexes are computed only once during initialization', () => {
	// Create spy functions to count compute calls
	const compute_spy = vi.fn((collection) => {
		return new Map(collection.all.map((item: Test_Item) => [item.name, item]));
	});

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'test_index',
				compute: compute_spy,
				result_schema: z.map(z.string(), item_schema),
			},
		],
		initial_items: [create_test_item('a1', 'c1'), create_test_item('a2', 'c2')],
	});

	// Verify compute was called exactly once during initialization
	expect(compute_spy).toHaveBeenCalledTimes(1);
	expect(collection.size).toBe(2);
});

test('Indexed_Collection - optimization - incremental updates avoid recomputing entire index', () => {
	// Create spies for the compute and on_add functions
	const compute_spy = vi.fn((collection) => {
		return collection.all.filter((item: Test_Item) => item.value > 10);
	});

	const on_add_spy = vi.fn((items, item) => {
		if (item.value > 10) {
			items.push(item);
		}
		return items;
	});

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_derived_index({
				key: 'high_value',
				compute: compute_spy,
				matches: (item) => item.value > 10,
				on_add: on_add_spy,
			}),
		],
		initial_items: [create_test_item('a1', 'c1', [], 15), create_test_item('a2', 'c2', [], 5)],
	});

	// Verify compute was called exactly once during initialization
	expect(compute_spy).toHaveBeenCalledTimes(1);

	// Add more items and check that compute isn't called again
	collection.add(create_test_item('a3', 'c3', [], 20));
	collection.add(create_test_item('a4', 'c4', [], 8));

	// Compute should still have been called only once
	expect(compute_spy).toHaveBeenCalledTimes(1);

	// on_add should have been called twice - once for each new item
	expect(on_add_spy).toHaveBeenCalledTimes(2);

	// Check that the index was correctly updated
	const high_value = collection.get_derived('high_value');
	expect(high_value.length).toBe(2);
	expect(high_value.some((item) => item.name === 'a1')).toBe(true);
	expect(high_value.some((item) => item.name === 'a3')).toBe(true);
});

test('Indexed_Collection - optimization - batch operations are more efficient', () => {
	// Create a collection with a multi-index
	const on_add_spy = vi.fn((map, item) => {
		const collection = map.get(item.category) || [];
		collection.push(item);
		map.set(item.category, collection);
		return map;
	});

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'by_category',
				type: 'multi',
				extractor: (item) => item.category,
				compute: (collection) => {
					const map = new Map();
					for (const item of collection.all) {
						const collection = map.get(item.category) || [];
						collection.push(item);
						map.set(item.category, collection);
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
		create_test_item(`item${i}`, i % 5 === 0 ? 'c1' : 'c2'),
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
		create_test_item(`more${i}`, i % 5 === 0 ? 'c1' : 'c2'),
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
			create_dynamic_index<Test_Item, (min_value: string) => Array<Test_Item>>({
				key: 'by_min_value',
				factory: (collection) => {
					return (min_value: string) => {
						const threshold = parseInt(min_value, 10);
						return collection.all.filter((item) => item.value >= threshold);
					};
				},
				query_schema: z.string(),
				result_schema: dynamic_function_schema,
			}),
		],
	});

	// Add test data
	for (let i = 0; i < 20; i++) {
		collection.add(create_test_item(`item${i}`, `c${i % 3}`, [], i * 5));
	}

	// Verify function index produces different results based on input
	const value_fn = collection.get_index<(threshold: string) => Array<Test_Item>>('by_min_value');

	// These should return different filtered subsets without storing separate copies
	expect(value_fn('10').length).not.toBe(value_fn('50').length);
	expect(value_fn('0').length).toBe(20); // All items
	expect(value_fn('50').length).toBe(10); // Half the items
	expect(value_fn('90').length).toBe(2); // Just the highest values
});

test('Indexed_Collection - optimization - memory usage with large datasets', () => {
	// This test creates a large dataset and verifies indexes work efficiently
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	// Create a large dataset (~1000 items)
	const large_dataset = Array.from({length: 1000}, (_, i) =>
		create_test_item(`item${i}`, `category${i % 10}`, [`thing${i % 20}`], i),
	);

	// Add them in one batch
	collection.add_many(large_dataset);

	// Create indexes after adding data
	collection.indexes.by_category = create_multi_index({
		key: 'by_category',
		extractor: (item: any) => item.category,
	}).compute(collection);

	// Verify the index contains the expected number of categories
	const category_index = collection.get_index<Map<string, Array<Test_Item>>>('by_category');
	expect(category_index.size).toBe(10); // 10 unique categories

	// Verify each category has the right number of items
	for (let i = 0; i < 10; i++) {
		expect(collection.where('by_category', `category${i}`).length).toBe(100); // 1000 items / 10 categories = 100 per category
	}
});
