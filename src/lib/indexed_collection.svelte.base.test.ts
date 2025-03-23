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
	key_text: string;
	group: string;
	tags: Array<string>;
	timestamp: Date;
	score: number;
}

// Helper function to create test items with predictable values
const create_test_item = (
	key_text: string,
	group: string,
	tags: Array<string> = [],
	score: number = 0,
): Test_Item => ({
	id: Uuid.parse(undefined),
	key_text,
	group,
	tags,
	timestamp: new Date(),
	score,
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

	// Check size and content
	expect(collection.size).toBe(2);
	// Use ID-based comparison instead of reference equality
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

test('Indexed_Collection - single index operations', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'by_key',
				extractor: (item) => item.key_text,
				query_schema: z.string(),
			}),
		],
	});

	// Add items with unique identifiers
	const item1 = create_test_item('a1', 'b1');
	const item2 = create_test_item('a2', 'b1');
	const item3 = create_test_item('a3', 'b2');

	collection.add(item1);
	collection.add(item2);
	collection.add(item3);

	// Test lookup by single index
	expect(collection.by_optional<string>('by_key', 'a1')?.id).toBe(item1.id);
	expect(collection.by_optional<string>('by_key', 'a2')?.id).toBe(item2.id);
	expect(collection.by_optional<string>('by_key', 'a3')?.id).toBe(item3.id);
	expect(collection.by_optional<string>('by_key', 'missing')).toBeUndefined();

	// Test the non-optional version that throws
	expect(() => collection.by<string>('by_key', 'missing')).toThrow();
	expect(collection.by<string>('by_key', 'a1').id).toBe(item1.id);

	// Test query method
	expect(collection.query<Test_Item, string>('by_key', 'a1').id).toBe(item1.id);

	// Test index update on removal
	collection.remove(item2.id);
	expect(collection.by_optional<string>('by_key', 'a2')).toBeUndefined();
	expect(collection.size).toBe(2);
});

test('Indexed_Collection - multi index operations', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_multi_index({
				key: 'by_group',
				extractor: (item) => item.group,
				query_schema: z.string(),
			}),
		],
	});

	// Add items with shared group keys
	const item1 = create_test_item('a1', 'b1');
	const item2 = create_test_item('a2', 'b1');
	const item3 = create_test_item('a3', 'b2');
	const item4 = create_test_item('a4', 'b2');

	collection.add(item1);
	collection.add(item2);
	collection.add(item3);
	collection.add(item4);

	// Test multi-index lookup
	expect(collection.where<string>('by_group', 'b1')).toHaveLength(2);
	const items_in_group1 = collection.where<string>('by_group', 'b1');
	expect(items_in_group1.some((item) => item.id === item1.id)).toBe(true);
	expect(items_in_group1.some((item) => item.id === item2.id)).toBe(true);

	expect(collection.where<string>('by_group', 'b2')).toHaveLength(2);
	const items_in_group2 = collection.where<string>('by_group', 'b2');
	expect(items_in_group2.some((item) => item.id === item3.id)).toBe(true);
	expect(items_in_group2.some((item) => item.id === item4.id)).toBe(true);

	// Test first/latest with limit
	expect(collection.first<string>('by_group', 'b1', 1)).toHaveLength(1);
	expect(collection.first<string>('by_group', 'b1', 1)[0].id).toBe(item1.id);
	expect(collection.latest<string>('by_group', 'b2', 1)).toHaveLength(1);
	expect(collection.latest<string>('by_group', 'b2', 1)[0].id).toBe(item4.id);

	// Test index update on removal
	collection.remove(item1.id);
	expect(collection.where<string>('by_group', 'b1')).toHaveLength(1);
	expect(collection.where<string>('by_group', 'b1')[0].id).toBe(item2.id);
});

test('Indexed_Collection - derived index operations', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_derived_index({
				key: 'high_score',
				compute: (collection) => collection.all.filter((item) => item.score > 5),
				matches: (item) => item.score > 5,
				sort: (a, b) => b.score - a.score,
				query_schema: z.void(),
				result_schema: item_array_schema,
			}),
		],
	});

	// Add items with various scores
	const medium_score_item = create_test_item('a1', 'b1', [], 8);
	const low_score_item = create_test_item('a2', 'b2', [], 3);
	const high_score_item = create_test_item('a3', 'b1', [], 10);
	const threshold_score_item = create_test_item('a4', 'b2', [], 6);

	collection.add(medium_score_item);
	collection.add(low_score_item);
	collection.add(high_score_item);
	collection.add(threshold_score_item);

	// Check derived index
	const high_scores = collection.get_derived('high_score');
	expect(high_scores).toHaveLength(3);
	// Compare by id instead of reference
	expect(high_scores[0].id).toBe(high_score_item.id); // Highest score first (10)
	expect(high_scores[1].id).toBe(medium_score_item.id); // Second score (8)
	expect(high_scores[2].id).toBe(threshold_score_item.id); // Third score (6)
	expect(high_scores.some((item) => item.id === low_score_item.id)).toBe(false); // Low score excluded (3)

	// Test direct access via get_index
	const high_scores_via_index = collection.get_index('high_score');
	expect(high_scores_via_index).toEqual(high_scores);

	// Test incremental update
	const new_high_score_item = create_test_item('a5', 'b1', [], 9);
	collection.add(new_high_score_item);

	const updated_high_scores = collection.get_derived('high_score');
	expect(updated_high_scores).toHaveLength(4);
	expect(updated_high_scores[0].id).toBe(high_score_item.id); // 10
	expect(updated_high_scores[1].id).toBe(new_high_score_item.id); // 9
	expect(updated_high_scores[2].id).toBe(medium_score_item.id); // 8
	expect(updated_high_scores[3].id).toBe(threshold_score_item.id); // 6

	// Test removal from derived index
	collection.remove(high_score_item.id);
	const scores_after_removal = collection.get_derived('high_score');
	expect(scores_after_removal).toHaveLength(3);
	expect(scores_after_removal[0].id).toBe(new_high_score_item.id); // Now highest score
});

test('Indexed_Collection - combined indexing strategies', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'by_key',
				extractor: (item) => item.key_text,
				query_schema: z.string(),
			}),
			create_multi_index({
				key: 'by_group',
				extractor: (item) => item.group,
				query_schema: z.string(),
			}),
			create_multi_index({
				key: 'by_tag',
				extractor: (item) => item.tags[0],
				query_schema: z.string(),
			}),
			create_derived_index({
				key: 'recent_high_scores',
				compute: (collection) => {
					return collection.all
						.filter((item) => item.score >= 8)
						.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());
				},
				matches: (item) => item.score >= 8,
				sort: (a, b) => b.timestamp.getTime() - a.timestamp.getTime(),
				query_schema: z.void(),
				result_schema: item_array_schema,
			}),
		],
	});

	// Create items with a mix of properties
	const high_score_item = create_test_item('a1', 'g1', ['t1', 't2'], 9);
	const mid_score_item = create_test_item('a2', 'g1', ['t3', 't4'], 7);
	const low_score_item = create_test_item('a3', 'g2', ['t5', 't6'], 3);
	const top_score_item = create_test_item('a4', 'g1', ['t7', 't8'], 10);

	collection.add_many([high_score_item, mid_score_item, low_score_item, top_score_item]);

	// Test single index lookup
	expect(collection.by_optional<string>('by_key', 'a1')?.id).toBe(high_score_item.id);

	// Test multi index lookup
	expect(collection.where<string>('by_group', 'g1')).toHaveLength(3);
	expect(
		collection.where<string>('by_tag', 't1').some((item) => item.id === high_score_item.id),
	).toBe(true);

	// Test derived index
	const high_scores = collection.get_derived('recent_high_scores');
	expect(high_scores).toHaveLength(2);
	expect(high_scores.some((item) => item.id === high_score_item.id)).toBe(true);
	expect(high_scores.some((item) => item.id === top_score_item.id)).toBe(true);
	expect(high_scores.some((item) => item.id === mid_score_item.id)).toBe(false); // score 7 is too low
});

test('Indexed_Collection - add_first and ordering', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	const first_item = create_test_item('a1', 'g1');
	const prepend_item = create_test_item('a2', 'g1');
	const append_item = create_test_item('a3', 'g1');

	// Add in specific order
	collection.add(first_item);
	collection.add_first(prepend_item);
	collection.add(append_item);

	// Check ordering using id comparison
	expect(collection.all[0].id).toBe(prepend_item.id);
	expect(collection.all[1].id).toBe(first_item.id);
	expect(collection.all[2].id).toBe(append_item.id);

	// Test insert_at
	const insert_item = create_test_item('a4', 'g1');
	collection.insert_at(insert_item, 1);

	expect(collection.all[0].id).toBe(prepend_item.id);
	expect(collection.all[1].id).toBe(insert_item.id);
	expect(collection.all[2].id).toBe(first_item.id);
	expect(collection.all[3].id).toBe(append_item.id);
});

test('Indexed_Collection - reorder items', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	const test_items = [
		create_test_item('a1', 'g1'),
		create_test_item('a2', 'g1'),
		create_test_item('a3', 'g1'),
		create_test_item('a4', 'g1'),
	];

	collection.add_many(test_items);

	// Initial order: a1, a2, a3, a4
	expect(collection.all[0].key_text).toBe('a1');
	expect(collection.all[3].key_text).toBe('a4');

	// Move 'a1' to position 2
	collection.reorder(0, 2);

	// New order should be: a2, a3, a1, a4
	expect(collection.all[0].key_text).toBe('a2');
	expect(collection.all[1].key_text).toBe('a3');
	expect(collection.all[2].key_text).toBe('a1');
	expect(collection.all[3].key_text).toBe('a4');
});

test('Indexed_Collection - function indexes', () => {
	// Test a function-based index using the new helper function
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			create_dynamic_index<Test_Item, (score_level: string) => Array<Test_Item>>({
				key: 'by_score_rank',
				factory: (collection) => {
					return (score_level: string) => {
						if (score_level === 'high') {
							return collection.all.filter((item) => item.score >= 8);
						} else if (score_level === 'medium') {
							return collection.all.filter((item) => item.score >= 4 && item.score < 8);
						} else {
							return collection.all.filter((item) => item.score < 4);
						}
					};
				},
				query_schema: z.string(),
				result_schema: dynamic_function_schema,
			}),
		],
	});

	// Add items with different score values
	collection.add(create_test_item('a1', 'g1', [], 10)); // High score
	collection.add(create_test_item('a2', 'g1', [], 8)); // High score
	collection.add(create_test_item('a3', 'g1', [], 7)); // Medium score
	collection.add(create_test_item('a4', 'g1', [], 5)); // Medium score
	collection.add(create_test_item('a5', 'g1', [], 3)); // Low score
	collection.add(create_test_item('a6', 'g1', [], 1)); // Low score

	// The index is a function that can be queried
	const rank_function = collection.get_index<(level: string) => Array<Test_Item>>('by_score_rank');

	// Test function index queries
	expect(rank_function('high')).toHaveLength(2);
	expect(rank_function('medium')).toHaveLength(2);
	expect(rank_function('low')).toHaveLength(2);

	// Test using the query method
	expect(collection.query<Array<Test_Item>, string>('by_score_rank', 'high')).toHaveLength(2);
	expect(collection.query<Array<Test_Item>, string>('by_score_rank', 'medium')).toHaveLength(2);
	expect(collection.query<Array<Test_Item>, string>('by_score_rank', 'low')).toHaveLength(2);
});

test('Indexed_Collection - complex data structures', () => {
	// Create a custom helper function for this specialized case
	const create_stats_index = <T extends Indexed_Item>(key: string) => ({
		key,
		compute: (collection: Indexed_Collection<T>) => {
			const items = collection.all;
			return {
				count: items.length,
				average_f: items.reduce((sum, item: any) => sum + item.score, 0) / (items.length || 1),
				b_values: new Set(items.map((item: any) => item.group)),
			};
		},
		query_schema: z.void(),
		result_schema: stats_schema,
		on_add: (stats: any, item: any) => {
			stats.count++;
			stats.average_f = (stats.average_f * (stats.count - 1) + item.score) / stats.count;
			stats.b_values.add(item.group);
			return stats;
		},
		on_remove: (stats: any, item: any, collection: Indexed_Collection<T>) => {
			stats.count--;
			if (stats.count === 0) {
				stats.average_f = 0;
			} else {
				stats.average_f = (stats.average_f * (stats.count + 1) - item.score) / stats.count;
			}

			// Rebuild b_values set if needed (we don't know if other items use this group)
			const all_group_values = new Set(
				collection.all.filter((i) => i.id !== item.id).map((i: any) => i.group),
			);
			stats.b_values = all_group_values;

			return stats;
		},
	});

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [create_stats_index<Test_Item>('stats')],
	});

	// Add items
	collection.add(create_test_item('a1', 'g1', [], 10));
	collection.add(create_test_item('a2', 'g2', [], 20));

	// Test complex index structure
	const stats = collection.get_index<{
		count: number;
		average_f: number;
		b_values: Set<string>;
	}>('stats');

	expect(stats.count).toBe(2);
	expect(stats.average_f).toBe(15);
	expect(stats.b_values.size).toBe(2);
	expect(stats.b_values.has('g1')).toBe(true);

	// Test updating the complex structure
	collection.add(create_test_item('a3', 'g1', [], 30));

	expect(stats.count).toBe(3);
	expect(stats.average_f).toBe(20);
	expect(stats.b_values.size).toBe(2);
});
