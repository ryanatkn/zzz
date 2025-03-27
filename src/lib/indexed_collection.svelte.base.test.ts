// @vitest-environment jsdom

import {test, expect, describe} from 'vitest';
import {z} from 'zod';

import {Indexed_Collection, type Indexed_Item} from '$lib/indexed_collection.svelte.js';
import {
	create_single_index,
	create_multi_index,
	create_derived_index,
	create_dynamic_index,
} from '$lib/indexed_collection_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';

// Mock item type that implements Indexed_Item
interface Test_Item {
	id: Uuid;
	text: string;
	category: string;
	list: Array<string>;
	date: Date;
	number: number;
}

// Helper function to create test items with predictable values
const create_item = (
	text: string,
	category: string,
	list: Array<string> = [],
	number: number = 0,
): Test_Item => ({
	id: Uuid.parse(undefined),
	text,
	category,
	list,
	date: new Date(),
	number,
});

// Helper functions for id-based equality checks
const has_item_with_id = (array: Array<Test_Item>, item: Test_Item): boolean => {
	return array.some((i) => i.id === item.id);
};

// Define common schemas for testing
const item_schema = z.custom<Test_Item>((val) => val && typeof val === 'object' && 'id' in val);
const item_array_schema = z.array(item_schema);
const dynamic_function_schema = z.function().args(z.string()).returns(z.array(item_schema));

const stats_schema = z.object({
	count: z.number(),
	average: z.number(),
	unique_values: z.custom<Set<string>>((val) => val instanceof Set),
});

describe('Indexed_Collection - Base Functionality', () => {
	test('basic operations with no indexes', () => {
		// Create a collection with no indexes
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

		// Add items
		const item1 = create_item('a1', 'c1');
		const item2 = create_item('a2', 'c2');

		collection.add(item1);
		collection.add(item2);

		// Check size and content
		expect(collection.size).toBe(2);
		// Use id-based comparison instead of reference equality
		expect(has_item_with_id(collection.all, item1)).toBe(true);
		expect(has_item_with_id(collection.all, item2)).toBe(true);

		// Test retrieval by id
		expect(collection.get(item1.id)?.id).toBe(item1.id);

		// Test removal
		expect(collection.remove(item1.id)).toBe(true);
		expect(collection.size).toBe(1);
		expect(collection.get(item1.id)).toBeUndefined();
		expect(collection.get(item2.id)?.id).toBe(item2.id);
	});

	test('single index operations', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_text',
					extractor: (item) => item.text,
					query_schema: z.string(),
				}),
			],
		});

		// Add items with unique identifiers
		const item1 = create_item('a1', 'c1');
		const item2 = create_item('a2', 'c1');
		const item3 = create_item('a3', 'c2');

		collection.add(item1);
		collection.add(item2);
		collection.add(item3);

		// Test lookup by single index
		expect(collection.by_optional<string>('by_text', 'a1')?.id).toBe(item1.id);
		expect(collection.by_optional<string>('by_text', 'a2')?.id).toBe(item2.id);
		expect(collection.by_optional<string>('by_text', 'a3')?.id).toBe(item3.id);
		expect(collection.by_optional<string>('by_text', 'missing')).toBeUndefined();

		// Test the non-optional version that throws
		expect(() => collection.by<string>('by_text', 'missing')).toThrow();
		expect(collection.by<string>('by_text', 'a1').id).toBe(item1.id);

		// Test query method
		expect(collection.query<Test_Item, string>('by_text', 'a1').id).toBe(item1.id);

		// Test index update on removal
		collection.remove(item2.id);
		expect(collection.by_optional<string>('by_text', 'a2')).toBeUndefined();
		expect(collection.size).toBe(2);
	});
});

describe('Indexed_Collection - Index Types', () => {
	test('multi index operations', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_multi_index({
					key: 'by_category',
					extractor: (item) => item.category,
					query_schema: z.string(),
				}),
			],
		});

		// Add items with shared category keys
		const item1 = create_item('a1', 'c1');
		const item2 = create_item('a2', 'c1');
		const item3 = create_item('a3', 'c2');
		const item4 = create_item('a4', 'c2');

		collection.add(item1);
		collection.add(item2);
		collection.add(item3);
		collection.add(item4);

		// Test multi-index lookup
		expect(collection.where<string>('by_category', 'c1')).toHaveLength(2);
		const c1_items = collection.where<string>('by_category', 'c1');
		expect(c1_items.some((item) => item.id === item1.id)).toBe(true);
		expect(c1_items.some((item) => item.id === item2.id)).toBe(true);

		expect(collection.where<string>('by_category', 'c2')).toHaveLength(2);
		const c2_items = collection.where<string>('by_category', 'c2');
		expect(c2_items.some((item) => item.id === item3.id)).toBe(true);
		expect(c2_items.some((item) => item.id === item4.id)).toBe(true);

		// Test first/latest with limit
		expect(collection.first<string>('by_category', 'c1', 1)).toHaveLength(1);
		expect(collection.first<string>('by_category', 'c1', 1)[0].id).toBe(item1.id);
		expect(collection.latest<string>('by_category', 'c2', 1)).toHaveLength(1);
		expect(collection.latest<string>('by_category', 'c2', 1)[0].id).toBe(item4.id);

		// Test index update on removal
		collection.remove(item1.id);
		expect(collection.where<string>('by_category', 'c1')).toHaveLength(1);
		expect(collection.where<string>('by_category', 'c1')[0].id).toBe(item2.id);
	});

	test('derived index operations', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_derived_index({
					key: 'high_numbers',
					compute: (collection) => collection.all.filter((item) => item.number > 5),
					matches: (item) => item.number > 5,
					sort: (a, b) => b.number - a.number,
					query_schema: z.void(),
					result_schema: item_array_schema,
				}),
			],
		});

		// Add items with various numbers
		const medium_item = create_item('a1', 'c1', [], 8);
		const low_item = create_item('a2', 'c2', [], 3);
		const high_item = create_item('a3', 'c1', [], 10);
		const threshold_item = create_item('a4', 'c2', [], 6);

		collection.add(medium_item);
		collection.add(low_item);
		collection.add(high_item);
		collection.add(threshold_item);

		// Check derived index
		const high_numbers = collection.get_derived('high_numbers');
		expect(high_numbers).toHaveLength(3);
		// Compare by id instead of reference
		expect(high_numbers[0].id).toBe(high_item.id); // Highest number first (10)
		expect(high_numbers[1].id).toBe(medium_item.id); // Second number (8)
		expect(high_numbers[2].id).toBe(threshold_item.id); // Third number (6)
		expect(high_numbers.some((item) => item.id === low_item.id)).toBe(false); // Low number excluded (3)

		// Test direct access via get_index
		const high_numbers_via_index = collection.get_index('high_numbers');
		expect(high_numbers_via_index).toEqual(high_numbers);

		// Test incremental update
		const new_high_item = create_item('a5', 'c1', [], 9);
		collection.add(new_high_item);

		const updated_high_numbers = collection.get_derived('high_numbers');
		expect(updated_high_numbers).toHaveLength(4);
		expect(updated_high_numbers[0].id).toBe(high_item.id); // 10
		expect(updated_high_numbers[1].id).toBe(new_high_item.id); // 9
		expect(updated_high_numbers[2].id).toBe(medium_item.id); // 8
		expect(updated_high_numbers[3].id).toBe(threshold_item.id); // 6

		// Test removal from derived index
		collection.remove(high_item.id);
		const numbers_after_removal = collection.get_derived('high_numbers');
		expect(numbers_after_removal).toHaveLength(3);
		expect(numbers_after_removal[0].id).toBe(new_high_item.id); // Now highest number
	});

	test('function indexes', () => {
		// Test a function-based index using the new helper function
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_dynamic_index<Test_Item, (range: string) => Array<Test_Item>>({
					key: 'by_range',
					factory: (collection) => {
						return (range: string) => {
							if (range === 'high') {
								return collection.all.filter((item) => item.number >= 8);
							} else if (range === 'medium') {
								return collection.all.filter((item) => item.number >= 4 && item.number < 8);
							} else {
								return collection.all.filter((item) => item.number < 4);
							}
						};
					},
					query_schema: z.string(),
					result_schema: dynamic_function_schema,
				}),
			],
		});

		// Add items with different number values
		collection.add(create_item('a1', 'c1', [], 10)); // High number
		collection.add(create_item('a2', 'c1', [], 8)); // High number
		collection.add(create_item('a3', 'c1', [], 7)); // Medium number
		collection.add(create_item('a4', 'c1', [], 5)); // Medium number
		collection.add(create_item('a5', 'c1', [], 3)); // Low number
		collection.add(create_item('a6', 'c1', [], 1)); // Low number

		// The index is a function that can be queried
		const range_function = collection.get_index<(range: string) => Array<Test_Item>>('by_range');

		// Test function index queries
		expect(range_function('high')).toHaveLength(2);
		expect(range_function('medium')).toHaveLength(2);
		expect(range_function('low')).toHaveLength(2);

		// Test using the query method
		expect(collection.query<Array<Test_Item>, string>('by_range', 'high')).toHaveLength(2);
		expect(collection.query<Array<Test_Item>, string>('by_range', 'medium')).toHaveLength(2);
		expect(collection.query<Array<Test_Item>, string>('by_range', 'low')).toHaveLength(2);
	});
});

describe('Indexed_Collection - Advanced Features', () => {
	test('combined indexing strategies', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_text',
					extractor: (item) => item.text,
					query_schema: z.string(),
				}),
				create_multi_index({
					key: 'by_category',
					extractor: (item) => item.category,
					query_schema: z.string(),
				}),
				create_multi_index({
					key: 'by_listitem',
					extractor: (item) => item.list[0],
					query_schema: z.string(),
				}),
				create_derived_index({
					key: 'recent_high_numbers',
					compute: (collection) => {
						return collection.all
							.filter((item) => item.number >= 8)
							.sort((a, b) => b.date.getTime() - a.date.getTime());
					},
					matches: (item) => item.number >= 8,
					sort: (a, b) => b.date.getTime() - a.date.getTime(),
					query_schema: z.void(),
					result_schema: item_array_schema,
				}),
			],
		});

		// Create items with a mix of properties
		const high_number_item = create_item('a1', 'c1', ['l1', 'l2'], 9);
		const mid_number_item = create_item('a2', 'c1', ['l3', 'l4'], 7);
		const low_number_item = create_item('a3', 'c2', ['l5', 'l6'], 3);
		const top_number_item = create_item('a4', 'c1', ['l7', 'l8'], 10);

		collection.add_many([high_number_item, mid_number_item, low_number_item, top_number_item]);

		// Test single index lookup
		expect(collection.by_optional<string>('by_text', 'a1')?.id).toBe(high_number_item.id);

		// Test multi index lookup
		expect(collection.where<string>('by_category', 'c1')).toHaveLength(3);
		expect(
			collection.where<string>('by_listitem', 'l1').some((item) => item.id === high_number_item.id),
		).toBe(true);

		// Test derived index
		const high_numbers = collection.get_derived('recent_high_numbers');
		expect(high_numbers).toHaveLength(2);
		expect(high_numbers.some((item) => item.id === high_number_item.id)).toBe(true);
		expect(high_numbers.some((item) => item.id === top_number_item.id)).toBe(true);
		expect(high_numbers.some((item) => item.id === mid_number_item.id)).toBe(false); // score 7 is too low
	});

	test('complex data structures', () => {
		// Create a custom helper function for this specialized case
		const create_stats_index = <T extends Indexed_Item>(key: string) => ({
			key,
			compute: (collection: Indexed_Collection<T>) => {
				const items = collection.all;
				return {
					count: items.length,
					average: items.reduce((sum, item: any) => sum + item.number, 0) / (items.length || 1),
					unique_values: new Set(items.map((item: any) => item.category)),
				};
			},
			query_schema: z.void(),
			result_schema: stats_schema,
			on_add: (stats: any, item: any) => {
				stats.count++;
				stats.average = (stats.average * (stats.count - 1) + item.number) / stats.count;
				stats.unique_values.add(item.category);
				return stats;
			},
			on_remove: (stats: any, item: any, collection: Indexed_Collection<T>) => {
				stats.count--;
				if (stats.count === 0) {
					stats.average = 0;
				} else {
					stats.average = (stats.average * (stats.count + 1) - item.number) / stats.count;
				}

				// Rebuild unique_values set if needed (we don't know if other items use this category)
				const all_unique_values = new Set(
					collection.all.filter((i) => i.id !== item.id).map((i: any) => i.category),
				);
				stats.unique_values = all_unique_values;

				return stats;
			},
		});

		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [create_stats_index<Test_Item>('stats')],
		});

		// Add items
		collection.add(create_item('a1', 'c1', [], 10));
		collection.add(create_item('a2', 'c2', [], 20));

		// Test complex index structure
		const stats = collection.get_index<{
			count: number;
			average: number;
			unique_values: Set<string>;
		}>('stats');

		expect(stats.count).toBe(2);
		expect(stats.average).toBe(15);
		expect(stats.unique_values.size).toBe(2);
		expect(stats.unique_values.has('c1')).toBe(true);

		// Test updating the complex structure
		collection.add(create_item('a3', 'c1', [], 30));

		expect(stats.count).toBe(3);
		expect(stats.average).toBe(20);
		expect(stats.unique_values.size).toBe(2);
	});
});

describe('Indexed_Collection - Array Operations', () => {
	test('add_first and ordering', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

		const first_item = create_item('a1', 'c1');
		const prepend_item = create_item('a2', 'c1');
		const append_item = create_item('a3', 'c1');

		// Add in specific order
		collection.add(first_item);
		collection.add_first(prepend_item);
		collection.add(append_item);

		// Check ordering using id comparison
		expect(collection.all[0].id).toBe(prepend_item.id);
		expect(collection.all[1].id).toBe(first_item.id);
		expect(collection.all[2].id).toBe(append_item.id);

		// Test insert_at
		const insert_item = create_item('a4', 'c1');
		collection.insert_at(insert_item, 1);

		expect(collection.all[0].id).toBe(prepend_item.id);
		expect(collection.all[1].id).toBe(insert_item.id);
		expect(collection.all[2].id).toBe(first_item.id);
		expect(collection.all[3].id).toBe(append_item.id);
	});

	test('reorder items', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

		const test_items = [
			create_item('a1', 'c1'),
			create_item('a2', 'c1'),
			create_item('a3', 'c1'),
			create_item('a4', 'c1'),
		];

		collection.add_many(test_items);

		// Initial order: a1, a2, a3, a4
		expect(collection.all[0].text).toBe('a1');
		expect(collection.all[3].text).toBe('a4');

		// Move 'a1' to position 2
		collection.reorder(0, 2);

		// New order should be: a2, a3, a1, a4
		expect(collection.all[0].text).toBe('a2');
		expect(collection.all[1].text).toBe('a3');
		expect(collection.all[2].text).toBe('a1');
		expect(collection.all[3].text).toBe('a4');
	});

	test('remove_first_many efficiently removes items from the beginning', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_multi_index({
					key: 'by_category',
					extractor: (item) => item.category,
					query_schema: z.string(),
				}),
			],
		});

		// Add 10 test items
		const items = [
			create_item('a1', 'c1', [], 1),
			create_item('a2', 'c1', [], 2),
			create_item('a3', 'c1', [], 3),
			create_item('a4', 'c2', [], 4),
			create_item('a5', 'c2', [], 5),
			create_item('a6', 'c2', [], 6),
			create_item('a7', 'c3', [], 7),
			create_item('a8', 'c3', [], 8),
			create_item('a9', 'c3', [], 9),
			create_item('a10', 'c3', [], 10),
		];

		collection.add_many(items);

		// Verify initial state
		expect(collection.size).toBe(10);
		expect(collection.where('by_category', 'c1').length).toBe(3);
		expect(collection.where('by_category', 'c2').length).toBe(3);
		expect(collection.where('by_category', 'c3').length).toBe(4);

		// Remove first 4 items
		const removed_count = collection.remove_first_many(4);

		// Verify the correct number of items were removed
		expect(removed_count).toBe(4);
		expect(collection.size).toBe(6);

		// Verify the correct items were removed (the first 4)
		expect(collection.all[0].text).toBe('a5');
		expect(collection.by_id.has(items[0].id)).toBe(false);
		expect(collection.by_id.has(items[1].id)).toBe(false);
		expect(collection.by_id.has(items[2].id)).toBe(false);
		expect(collection.by_id.has(items[3].id)).toBe(false);
		expect(collection.by_id.has(items[4].id)).toBe(true);

		// Verify indexes were properly updated
		expect(collection.where('by_category', 'c1').length).toBe(0); // All c1 items removed
		expect(collection.where('by_category', 'c2').length).toBe(2); // One c2 item removed
		expect(collection.where('by_category', 'c3').length).toBe(4); // No c3 items removed

		// Test removing more items than exist
		const remaining_count = collection.remove_first_many(10);
		expect(remaining_count).toBe(6);
		expect(collection.size).toBe(0);
		expect(collection.all).toEqual([]);

		// Test removing from empty collection
		const no_items_removed = collection.remove_first_many(5);
		expect(no_items_removed).toBe(0);
	});
});
