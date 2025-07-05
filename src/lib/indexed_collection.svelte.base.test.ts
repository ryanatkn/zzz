// @slop Claude Sonnet 3.7

// @vitest-environment jsdom

import {test, expect, describe} from 'vitest';
import {z} from 'zod';

import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {
	create_single_index,
	create_multi_index,
	create_derived_index,
	create_dynamic_index,
	type Indexed_Item,
} from '$lib/indexed_collection_helpers.svelte.js';
import {create_uuid, Uuid} from '$lib/zod_helpers.js';

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
	id: create_uuid(),
	text,
	category,
	list,
	date: new Date(),
	number,
});

// Helper functions for id-based equality checks
const has_item_with_id = (items: Iterable<Test_Item>, item: Test_Item): boolean => {
	for (const i of items) {
		if (i.id === item.id) return true;
	}
	return false;
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
		// Use id-based comparison with by_id.values()
		expect(has_item_with_id(collection.by_id.values(), item1)).toBe(true);
		expect(has_item_with_id(collection.by_id.values(), item2)).toBe(true);

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
		expect(collection.latest<string>('by_category', 'c2', 1)).toHaveLength(1);

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
					compute: (collection) => {
						const result = [];
						for (const item of collection.by_id.values()) {
							if (item.number > 5) {
								result.push(item);
							}
						}
						return result;
					},
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
		const high_numbers = collection.derived_index('high_numbers');
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

		const updated_high_numbers = collection.derived_index('high_numbers');
		expect(updated_high_numbers).toHaveLength(4);
		expect(updated_high_numbers[0].id).toBe(high_item.id); // 10
		expect(updated_high_numbers[1].id).toBe(new_high_item.id); // 9
		expect(updated_high_numbers[2].id).toBe(medium_item.id); // 8
		expect(updated_high_numbers[3].id).toBe(threshold_item.id); // 6

		// Test removal from derived index
		collection.remove(high_item.id);
		const numbers_after_removal = collection.derived_index('high_numbers');
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
							const result = [];
							for (const item of collection.by_id.values()) {
								if (range === 'high' && item.number >= 8) {
									result.push(item);
								} else if (range === 'medium' && item.number >= 4 && item.number < 8) {
									result.push(item);
								} else if (range === 'low' && item.number < 4) {
									result.push(item);
								}
							}
							return result;
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
						const result = [];
						for (const item of collection.by_id.values()) {
							if (item.number >= 8) {
								result.push(item);
							}
						}
						return result.sort((a, b) => b.date.getTime() - a.date.getTime());
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
		const high_numbers = collection.derived_index('recent_high_numbers');
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
				const items = [...collection.by_id.values()];
				return {
					count: items.length,
					average: items.reduce((sum, item: any) => sum + item.number, 0) / (items.length || 1),
					unique_values: new Set(items.map((item: any) => item.category)),
				};
			},
			query_schema: z.void(),
			result_schema: stats_schema,
			onadd: (stats: any, item: any) => {
				stats.count++;
				stats.average = (stats.average * (stats.count - 1) + item.number) / stats.count;
				stats.unique_values.add(item.category);
				return stats;
			},
			onremove: (stats: any, item: any, collection: Indexed_Collection<T>) => {
				stats.count--;
				if (stats.count === 0) {
					stats.average = 0;
				} else {
					stats.average = (stats.average * (stats.count + 1) - item.number) / stats.count;
				}

				// Rebuild unique_values set if needed (we don't know if other items use this category)
				const all_unique_values: Set<string> = new Set();
				for (const i of collection.by_id.values()) {
					if (i.id !== item.id) {
						all_unique_values.add((i as any).category);
					}
				}
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

	test('batch operations', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_multi_index({
					key: 'by_category',
					extractor: (item) => item.category,
					query_schema: z.string(),
				}),
			],
		});

		// Create test items
		const items = [
			create_item('a1', 'c1', [], 1),
			create_item('a2', 'c1', [], 2),
			create_item('a3', 'c1', [], 3),
			create_item('a4', 'c2', [], 4),
			create_item('a5', 'c2', [], 5),
		];

		// Add multiple items at once
		collection.add_many(items);

		// Verify all items were added
		expect(collection.size).toBe(5);
		expect(collection.where('by_category', 'c1').length).toBe(3);
		expect(collection.where('by_category', 'c2').length).toBe(2);

		// Test removing multiple items at once
		const ids_to_remove = [items[0].id, items[2].id, items[4].id];
		const removed_count = collection.remove_many(ids_to_remove);

		expect(removed_count).toBe(3);
		expect(collection.size).toBe(2);

		// Verify specific items were removed
		expect(collection.has(items[0].id)).toBe(false);
		expect(collection.has(items[1].id)).toBe(true);
		expect(collection.has(items[2].id)).toBe(false);
		expect(collection.has(items[3].id)).toBe(true);
		expect(collection.has(items[4].id)).toBe(false);

		// Verify indexes were properly updated
		expect(collection.where('by_category', 'c1').length).toBe(1);
		expect(collection.where('by_category', 'c2').length).toBe(1);
	});
});
