// @vitest-environment jsdom

import {test, expect} from 'vitest';
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
	a: string;
	b: string;
	c: Array<string>;
	e: Date;
	f: number;
}

// Helper function to create test items with predictable values
const create_test_item = (
	a: string,
	b: string,
	c: Array<string> = [],
	f: number = 0,
): Test_Item => ({
	id: Uuid.parse(undefined),
	a,
	b,
	c,
	e: new Date(),
	f,
});

// Helper functions for ID-based equality checks
const has_item_with_id = (array: Array<Test_Item>, item: Test_Item): boolean => {
	return array.some((i) => i.id === item.id);
};

// Define common schemas for testing
const item_schema = z.custom<Test_Item>((val) => val && typeof val === 'object' && 'id' in val);
const item_array_schema = z.array(item_schema);

// Fix: Change function schema to properly match the expected return type
const dynamic_function_schema = z.function().args(z.string()).returns(z.array(item_schema));

const stats_schema = z.object({
	count: z.number(),
	average_f: z.number(),
	b_values: z.custom<Set<string>>((val) => val instanceof Set),
});

test('Indexed_Collection - basic operations with no indexes', () => {
	// Create a collection with no indexes
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	// Add items
	const item1 = create_test_item('a1', 'b1');
	const item2 = create_test_item('a2', 'b2');

	collection.add(item1);
	collection.add(item2);

	// Check size and contents
	expect(collection.size).toBe(2);
	// Use ID-based comparison instead of reference equality
	expect(has_item_with_id(collection.all, item1)).toBe(true);
	expect(has_item_with_id(collection.all, item2)).toBe(true);

	// Test retrieval by ID
	expect(collection.get(item1.id)?.id).toBe(item1.id);

	// Test removal
	expect(collection.remove(item1.id)).toBe(true);
	expect(collection.size).toBe(1);
	expect(collection.get(item1.id)).toBeUndefined();
	expect(collection.get(item2.id)?.id).toBe(item2.id);
});

test('Indexed_Collection - single index operations', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'by_a',
				extractor: (item) => item.a,
				query_schema: z.string(),
			}),
		],
	});

	// Add items with unique names
	const item1 = create_test_item('a1', 'b1');
	const item2 = create_test_item('a2', 'b1');
	const item3 = create_test_item('a3', 'b2');

	collection.add(item1);
	collection.add(item2);
	collection.add(item3);

	// Test lookup by single index
	expect(collection.by_optional<string>('by_a', 'a1')?.id).toBe(item1.id);
	expect(collection.by_optional<string>('by_a', 'a2')?.id).toBe(item2.id);
	expect(collection.by_optional<string>('by_a', 'a3')?.id).toBe(item3.id);
	expect(collection.by_optional<string>('by_a', 'missing')).toBeUndefined();

	// Test the non-optional version that throws
	expect(() => collection.by<string>('by_a', 'missing')).toThrow();
	expect(collection.by<string>('by_a', 'a1').id).toBe(item1.id);

	// Test query method
	expect(collection.query<Test_Item, string>('by_a', 'a1').id).toBe(item1.id);

	// Test index update on removal
	collection.remove(item2.id);
	expect(collection.by_optional<string>('by_a', 'a2')).toBeUndefined();
	expect(collection.size).toBe(2);
});

test('Indexed_Collection - multi index operations', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_multi_index({
				key: 'by_b',
				extractor: (item) => item.b,
				query_schema: z.string(),
			}),
		],
	});

	// Add items with shared categories
	const item1 = create_test_item('a1', 'b1');
	const item2 = create_test_item('a2', 'b1');
	const item3 = create_test_item('a3', 'b2');
	const item4 = create_test_item('a4', 'b2');

	collection.add(item1);
	collection.add(item2);
	collection.add(item3);
	collection.add(item4);

	// Test multi-index lookup
	expect(collection.where<string>('by_b', 'b1')).toHaveLength(2);
	const b1_items = collection.where<string>('by_b', 'b1');
	expect(b1_items.some((item) => item.id === item1.id)).toBe(true);
	expect(b1_items.some((item) => item.id === item2.id)).toBe(true);

	expect(collection.where<string>('by_b', 'b2')).toHaveLength(2);
	const b2_items = collection.where<string>('by_b', 'b2');
	expect(b2_items.some((item) => item.id === item3.id)).toBe(true);
	expect(b2_items.some((item) => item.id === item4.id)).toBe(true);

	// Test first/latest with limit
	expect(collection.first<string>('by_b', 'b1', 1)).toHaveLength(1);
	expect(collection.first<string>('by_b', 'b1', 1)[0].id).toBe(item1.id);
	expect(collection.latest<string>('by_b', 'b2', 1)).toHaveLength(1);
	expect(collection.latest<string>('by_b', 'b2', 1)[0].id).toBe(item4.id);

	// Test index update on removal
	collection.remove(item1.id);
	expect(collection.where<string>('by_b', 'b1')).toHaveLength(1);
	expect(collection.where<string>('by_b', 'b1')[0].id).toBe(item2.id);
});

test('Indexed_Collection - derived index operations', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_derived_index({
				key: 'high_f',
				compute: (collection) => collection.all.filter((item) => item.f > 5),
				matches: (item) => item.f > 5,
				sort: (a, b) => b.f - a.f,
				query_schema: z.void(),
				result_schema: item_array_schema,
			}),
		],
	});

	// Add items with various priorities
	const item1 = create_test_item('a1', 'b1', [], 8);
	const item2 = create_test_item('a2', 'b2', [], 3);
	const item3 = create_test_item('a3', 'b1', [], 10);
	const item4 = create_test_item('a4', 'b2', [], 6);

	collection.add(item1);
	collection.add(item2);
	collection.add(item3);
	collection.add(item4);

	// Check derived index
	const high_f = collection.get_derived('high_f');
	expect(high_f).toHaveLength(3);
	// Compare by ID instead of reference
	expect(high_f[0].id).toBe(item3.id); // Highest f first (10)
	expect(high_f[1].id).toBe(item1.id); // Second f (8)
	expect(high_f[2].id).toBe(item4.id); // Third f (6)
	expect(high_f.some((item) => item.id === item2.id)).toBe(false); // Low f excluded (3)

	// Test direct access via get_index
	const high_f_via_index = collection.get_index('high_f');
	expect(high_f_via_index).toEqual(high_f);

	// Test incremental update
	const item5 = create_test_item('a5', 'b1', [], 9);
	collection.add(item5);

	const updated_high_f = collection.get_derived('high_f');
	expect(updated_high_f).toHaveLength(4);
	expect(updated_high_f[0].id).toBe(item3.id); // 10
	expect(updated_high_f[1].id).toBe(item5.id); // 9
	expect(updated_high_f[2].id).toBe(item1.id); // 8
	expect(updated_high_f[3].id).toBe(item4.id); // 6

	// Test removal from derived index
	collection.remove(item3.id);
	const after_remove = collection.get_derived('high_f');
	expect(after_remove).toHaveLength(3);
	expect(after_remove[0].id).toBe(item5.id); // Now highest f
});

test('Indexed_Collection - combined indexing strategies', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'by_a',
				extractor: (item) => item.a,
				query_schema: z.string(),
			}),
			create_multi_index({
				key: 'by_b',
				extractor: (item) => item.b,
				query_schema: z.string(),
			}),
			create_multi_index({
				key: 'by_c',
				extractor: (item) => item.c[0],
				query_schema: z.string(),
			}),
			create_derived_index({
				key: 'recent_high_f',
				compute: (collection) => {
					return collection.all
						.filter((item) => item.f >= 8)
						.sort((a, b) => b.e.getTime() - a.e.getTime());
				},
				matches: (item) => item.f >= 8,
				sort: (a, b) => b.e.getTime() - a.e.getTime(),
				query_schema: z.void(),
				result_schema: item_array_schema,
			}),
		],
	});

	// Create items with a mix of properties
	const item1 = create_test_item('a1', 'b1', ['c1', 'c2'], 9);
	const item2 = create_test_item('a2', 'b1', ['c3', 'c4'], 7);
	const item3 = create_test_item('a3', 'b2', ['c5', 'c6'], 3);
	const item4 = create_test_item('a4', 'b1', ['c7', 'c8'], 10);

	collection.add_many([item1, item2, item3, item4]);

	// Test single index lookup
	expect(collection.by_optional<string>('by_a', 'a1')?.id).toBe(item1.id);

	// Test multi index lookup
	expect(collection.where<string>('by_b', 'b1')).toHaveLength(3);
	expect(collection.where<string>('by_c', 'c1').some((item) => item.id === item1.id)).toBe(true);

	// Test derived index
	const high_f = collection.get_derived('recent_high_f');
	expect(high_f).toHaveLength(2);
	expect(high_f.some((item) => item.id === item1.id)).toBe(true);
	expect(high_f.some((item) => item.id === item4.id)).toBe(true);
	expect(high_f.some((item) => item.id === item2.id)).toBe(false); // f 7 is too low
});

test('Indexed_Collection - add_first and ordering', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	const item1 = create_test_item('a1', 'b1');
	const item2 = create_test_item('a2', 'b1');
	const item3 = create_test_item('a3', 'b1');

	// Add in specific order
	collection.add(item1);
	collection.add_first(item2);
	collection.add(item3);

	// Check ordering using ID comparison
	expect(collection.all[0].id).toBe(item2.id);
	expect(collection.all[1].id).toBe(item1.id);
	expect(collection.all[2].id).toBe(item3.id);

	// Test insert_at
	const item4 = create_test_item('a4', 'b1');
	collection.insert_at(item4, 1);

	expect(collection.all[0].id).toBe(item2.id);
	expect(collection.all[1].id).toBe(item4.id);
	expect(collection.all[2].id).toBe(item1.id);
	expect(collection.all[3].id).toBe(item3.id);
});

test('Indexed_Collection - reorder items', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	const items = [
		create_test_item('a1', 'b1'),
		create_test_item('a2', 'b1'),
		create_test_item('a3', 'b1'),
		create_test_item('a4', 'b1'),
	];

	collection.add_many(items);

	// Initial order: a1, a2, a3, a4
	expect(collection.all[0].a).toBe('a1');
	expect(collection.all[3].a).toBe('a4');

	// Move 'a1' to position 2
	collection.reorder(0, 2);

	// New order should be: a2, a3, a1, a4
	expect(collection.all[0].a).toBe('a2');
	expect(collection.all[1].a).toBe('a3');
	expect(collection.all[2].a).toBe('a1');
	expect(collection.all[3].a).toBe('a4');
});

test('Indexed_Collection - function indexes', () => {
	// Test a function-based index using the new helper function
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_dynamic_index<Test_Item, (f_level: string) => Array<Test_Item>>({
				key: 'by_f_rank',
				factory: (collection) => {
					return (f_level: string) => {
						if (f_level === 'high') {
							return collection.all.filter((item) => item.f >= 8);
						} else if (f_level === 'medium') {
							return collection.all.filter((item) => item.f >= 4 && item.f < 8);
						} else {
							return collection.all.filter((item) => item.f < 4);
						}
					};
				},
				query_schema: z.string(),
				result_schema: dynamic_function_schema,
			}),
		],
	});

	// Add items with different priorities
	collection.add(create_test_item('a1', 'b1', [], 10));
	collection.add(create_test_item('a2', 'b1', [], 8));
	collection.add(create_test_item('a3', 'b1', [], 7));
	collection.add(create_test_item('a4', 'b1', [], 5));
	collection.add(create_test_item('a5', 'b1', [], 3));
	collection.add(create_test_item('a6', 'b1', [], 1));

	// The index is a function that can be queried
	const f_fn = collection.get_index<(level: string) => Array<Test_Item>>('by_f_rank');

	// Test function index queries
	expect(f_fn('high')).toHaveLength(2);
	expect(f_fn('medium')).toHaveLength(2);
	expect(f_fn('low')).toHaveLength(2);

	// Test using the query method
	expect(collection.query<Array<Test_Item>, string>('by_f_rank', 'high')).toHaveLength(2);
	expect(collection.query<Array<Test_Item>, string>('by_f_rank', 'medium')).toHaveLength(2);
	expect(collection.query<Array<Test_Item>, string>('by_f_rank', 'low')).toHaveLength(2);
});

test('Indexed_Collection - complex data structures', () => {
	// Create a custom helper function for this specialized case
	const create_stats_index = <T extends Indexed_Item>(key: string) => ({
		key,
		compute: (collection: Indexed_Collection<T>) => {
			const items = collection.all;
			return {
				count: items.length,
				average_f: items.reduce((sum, item: any) => sum + item.f, 0) / (items.length || 1),
				b_values: new Set(items.map((item: any) => item.b)),
			};
		},
		query_schema: z.void(),
		result_schema: stats_schema,
		on_add: (stats: any, item: any) => {
			stats.count++;
			stats.average_f = (stats.average_f * (stats.count - 1) + item.f) / stats.count;
			stats.b_values.add(item.b);
			return stats;
		},
		on_remove: (stats: any, item: any, collection: Indexed_Collection<T>) => {
			stats.count--;
			if (stats.count === 0) {
				stats.average_f = 0;
			} else {
				stats.average_f = (stats.average_f * (stats.count + 1) - item.f) / stats.count;
			}

			// Rebuild b_values set if needed (we don't know if other items use this category)
			const all_b_values = new Set(
				collection.all.filter((i) => i.id !== item.id).map((i: any) => i.b),
			);
			stats.b_values = all_b_values;

			return stats;
		},
	});

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [create_stats_index<Test_Item>('stats')],
	});

	// Add items
	collection.add(create_test_item('a1', 'b1', [], 10));
	collection.add(create_test_item('a2', 'b2', [], 20));

	// Test complex index structure
	const stats = collection.get_index<{
		count: number;
		average_f: number;
		b_values: Set<string>;
	}>('stats');

	expect(stats.count).toBe(2);
	expect(stats.average_f).toBe(15);
	expect(stats.b_values.size).toBe(2);
	expect(stats.b_values.has('b1')).toBe(true);

	// Test updating the complex structure
	collection.add(create_test_item('a3', 'b1', [], 30));

	expect(stats.count).toBe(3);
	expect(stats.average_f).toBe(20);
	expect(stats.b_values.size).toBe(2);
});
