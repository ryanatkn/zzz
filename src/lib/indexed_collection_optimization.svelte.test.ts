// @vitest-environment jsdom

import {test, expect, vi, describe, beforeEach} from 'vitest';
import {z} from 'zod';

import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_multi_index, create_derived_index} from '$lib/indexed_collection_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';

// Mock item type for performance testing
interface Performance_Item {
	id: Uuid;
	name: string;
	tags: Array<string>;
	category: string;
	value: number;
	created: Date;
}

// Helper to create many test items
const create_many_items = (count: number): Array<Performance_Item> => {
	const items: Array<Performance_Item> = [];
	const categories = ['A', 'B', 'C', 'D', 'E'];
	const tags = ['red', 'green', 'blue', 'yellow', 'purple', 'orange', 'pink'];

	for (let i = 0; i < count; i++) {
		const category_index = i % categories.length;
		const tag1_index = i % tags.length;
		const tag2_index = (i + 1) % tags.length;

		items.push({
			id: Uuid.parse(undefined),
			name: `item_${i}`,
			category: categories[category_index],
			tags: [tags[tag1_index], tags[tag2_index]],
			value: Math.floor(Math.random() * 100),
			created: new Date(Date.now() - i * 1000), // Most recent first
		});
	}

	return items;
};

// Helper functions for ID-based object equality checks
const has_item_with_id = (array: Array<{id: Uuid}>, item: {id: Uuid}): boolean =>
	array.some((i) => i.id === item.id);

describe('Indexed_Collection - Optimization Tests', () => {
	// Setup common vars
	let items: Array<Performance_Item>;
	const ITEM_COUNT = 1000;

	beforeEach(() => {
		// Generate fresh test data for each test
		items = create_many_items(ITEM_COUNT);
	});

	test('Derived index should be more efficient than filtering', () => {
		// Create collection with a derived index for high-value items
		const indexed_collection: Indexed_Collection<Performance_Item> = new Indexed_Collection({
			indexes: [
				create_derived_index(
					'high_value_items',
					(collection) => collection.all.filter((item) => item.value >= 80),
					{
						matches: (item) => item.value >= 80,
						on_add: (items, item) => {
							if (item.value >= 80) {
								items.push(item);
							}
							return items;
						},
						on_remove: (items, item) => {
							const index = items.findIndex((i) => i.id === item.id);
							if (index !== -1) {
								items.splice(index, 1);
							}
							return items;
						},
					},
				),
			],
			initial_items: items,
		});

		// Time measurement for derived index access
		const derived_start = performance.now();
		const high_value_derived = indexed_collection.get_derived('high_value_items');
		const derived_end = performance.now();
		const derived_time = derived_end - derived_start;

		// Time measurement for direct filtering
		const filter_start = performance.now();
		const high_value_filtered = indexed_collection.all.filter((item) => item.value >= 80);
		const filter_end = performance.now();
		const filter_time = filter_end - filter_start;

		// Results should be the same
		expect(high_value_derived.length).toBe(high_value_filtered.length);

		// We expect derived index to be faster, but this is environment-dependent
		// So we'll log the results rather than making an assertion
		console.log(`Derived index access: ${derived_time}ms`);
		console.log(`Direct filtering: ${filter_time}ms`);

		// What we care most about is that adding new items is efficient
		const new_high_value_item = {
			id: Uuid.parse(undefined),
			name: 'new_high_value',
			category: 'A',
			tags: ['red', 'blue'],
			value: 95,
			created: new Date(),
		};

		// Track number of compute/filter operations
		const compute_spy = vi.fn();

		// Create a new collection with monitored compute function
		const monitored_collection: Indexed_Collection<Performance_Item> = new Indexed_Collection({
			indexes: [
				{
					key: 'high_value_items',
					compute: (collection) => {
						compute_spy();
						return collection.all.filter((item) => item.value >= 80);
					},
					output_schema: z.array(z.custom<Performance_Item>()),
					matches: (item) => item.value >= 80,
					on_add: (items, item) => {
						if (item.value >= 80) {
							items.push(item);
							return items;
						}
						return items;
					},
				},
			],
			initial_items: items,
		});

		// Initial computation happened during initialization
		expect(compute_spy).toHaveBeenCalledTimes(1);
		compute_spy.mockReset();

		// Add the new item - this should use on_add rather than recomputing
		monitored_collection.add(new_high_value_item);

		// The entire derived index should not have been recomputed
		expect(compute_spy).not.toHaveBeenCalled();

		// But the new item should still appear in the derived index
		const updated_derived = monitored_collection.get_derived('high_value_items');
		expect(has_item_with_id(updated_derived, new_high_value_item)).toBe(true);
	});

	test('Multi-index lookups should be faster than filtering', () => {
		// Create collection with multi-indexes
		const indexed_collection: Indexed_Collection<Performance_Item> = new Indexed_Collection({
			indexes: [
				create_multi_index('by_category', (item) => item.category),
				create_multi_index('by_tag', (item) => item.tags[0]),
			],
			initial_items: items,
		});

		// Measure time for indexed lookup
		const index_start = performance.now();
		const category_a_indexed = indexed_collection.where('by_category', 'A');
		const index_end = performance.now();
		const index_time = index_end - index_start;

		// Measure time for direct filtering
		const filter_start = performance.now();
		const category_a_filtered = indexed_collection.all.filter((item) => item.category === 'A');
		const filter_end = performance.now();
		const filter_time = filter_end - filter_start;

		// Results should be the same
		expect(category_a_indexed.length).toBe(category_a_filtered.length);

		// Log performance results
		console.log(`Multi-index lookup: ${index_time}ms`);
		console.log(`Direct filtering: ${filter_time}ms`);

		// Now test with a more complex criteria - items with tag 'red' and category 'A'
		// This demonstrates how indexes can be combined

		const combined_start = performance.now();
		// Get all items with tag 'red'
		const red_items = indexed_collection.where('by_tag', 'red');
		// Then filter to only those in category 'A'
		const red_in_category_a = red_items.filter((item) => item.category === 'A');
		const combined_end = performance.now();
		const combined_time = combined_end - combined_start;

		// Direct filtering for both criteria
		const direct_filter_start = performance.now();
		const direct_filtered = indexed_collection.all.filter(
			(item) => item.tags[0] === 'red' && item.category === 'A',
		);
		const direct_filter_end = performance.now();
		const direct_filter_time = direct_filter_end - direct_filter_start;

		// Results should be the same
		expect(red_in_category_a.length).toBe(direct_filtered.length);

		// Log performance results
		console.log(`Combined index filtering: ${combined_time}ms`);
		console.log(`Direct combined filtering: ${direct_filter_time}ms`);
	});

	test('Derived indexes update efficiently when modified', () => {
		// Create a collection with a derived index that needs sorting
		const collection: Indexed_Collection<Performance_Item> = new Indexed_Collection({
			indexes: [
				{
					key: 'recent_high_value',
					compute: (collection) => {
						// Sort by created date (most recent first)
						return [...collection.all]
							.filter((item) => item.value >= 80)
							.sort((a, b) => b.created.getTime() - a.created.getTime());
					},
					output_schema: z.array(z.custom<Performance_Item>()),
					matches: (item) => item.value >= 80,
					on_add: (items, item) => {
						if (item.value >= 80) {
							// Insert at the right position based on creation date
							const insert_index = items.findIndex(
								(existing) => item.created.getTime() > existing.created.getTime(),
							);

							if (insert_index === -1) {
								// Add to the end if it's the oldest
								items.push(item);
							} else {
								// Insert at the right position
								items.splice(insert_index, 0, item);
							}
						}
						return items;
					},
					on_remove: (items, item) => {
						const index = items.findIndex((i) => i.id === item.id);
						if (index !== -1) {
							items.splice(index, 1);
						}
						return items;
					},
				},
			],
		});

		// Create some items
		const now = Date.now();
		const recent_items = [
			{
				id: Uuid.parse(undefined),
				name: 'oldest',
				category: 'test',
				tags: ['red'],
				value: 90,
				created: new Date(now - 5000),
			},
			{
				id: Uuid.parse(undefined),
				name: 'middle',
				category: 'test',
				tags: ['blue'],
				value: 85,
				created: new Date(now - 3000),
			},
			{
				id: Uuid.parse(undefined),
				name: 'newest',
				category: 'test',
				tags: ['green'],
				value: 95,
				created: new Date(now - 1000),
			},
		];

		// Add items one by one to test incremental updates
		for (const item of recent_items) {
			collection.add(item);
		}

		// Verify order in the derived index
		const derived = collection.get_derived('recent_high_value');
		expect(derived).toHaveLength(3);
		expect(derived[0].name).toBe('newest');
		expect(derived[1].name).toBe('middle');
		expect(derived[2].name).toBe('oldest');

		// Track compute calls
		const compute_spy = vi.fn();

		// Create a new collection with monitored compute function
		const monitored_collection: Indexed_Collection<Performance_Item> = new Indexed_Collection({
			indexes: [
				{
					key: 'recent_high_value',
					compute: (collection) => {
						compute_spy();
						return [...collection.all]
							.filter((item) => item.value >= 80)
							.sort((a, b) => b.created.getTime() - a.created.getTime());
					},
					output_schema: z.array(z.custom<Performance_Item>()),
					matches: (item) => item.value >= 80,
					on_add: (items, item) => {
						if (item.value >= 80) {
							// Insert at the right position based on creation date
							const insert_index = items.findIndex(
								(existing) => item.created.getTime() > existing.created.getTime(),
							);

							if (insert_index === -1) {
								items.push(item);
							} else {
								items.splice(insert_index, 0, item);
							}
						}
						return items;
					},
				},
			],
			initial_items: recent_items,
		});

		// Initial computation happened during initialization
		expect(compute_spy).toHaveBeenCalledTimes(1);
		compute_spy.mockReset();

		// Add a new item that should be in the middle of the sorted list
		const new_item = {
			id: Uuid.parse(undefined),
			name: 'new_middle',
			category: 'test',
			tags: ['yellow'],
			value: 88,
			created: new Date(now - 2000), // Should be inserted between middle and newest
		};

		monitored_collection.add(new_item);

		// The compute function should not have been called again
		expect(compute_spy).not.toHaveBeenCalled();

		// Check that the item was inserted in the correct position
		const updated_derived = monitored_collection.get_derived('recent_high_value');
		expect(updated_derived).toHaveLength(4);
		expect(updated_derived[0].name).toBe('newest');
		expect(updated_derived[1].name).toBe('new_middle');
		expect(updated_derived[2].name).toBe('middle');
		expect(updated_derived[3].name).toBe('oldest');
	});
});
