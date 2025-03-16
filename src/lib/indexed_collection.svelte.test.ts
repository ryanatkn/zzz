// @vitest-environment jsdom

import {test, expect} from 'vitest';
import {z} from 'zod';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_single_index, create_multi_index} from '$lib/indexed_collection_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';
import {SvelteMap} from 'svelte/reactivity';

// Mock item type that implements Indexed_Item
interface Test_Item {
	id: Uuid;
	name: string;
	category: string;
	tags: Array<string>;
	created: Date;
	priority: number;
}

// Helper function to create test items with predictable values
const create_test_item = (
	name: string,
	category: string,
	tags: Array<string> = [],
	priority: number = 0,
): Test_Item => ({
	id: Uuid.parse(undefined),
	name,
	category,
	tags,
	created: new Date(),
	priority,
});

// Helper functions for ID-based equality checks
const has_item_with_id = (array: Array<Test_Item>, item: Test_Item): boolean => {
	return array.some((i) => i.id === item.id);
};

test('Indexed_Collection - basic operations with no indexes', () => {
	// Create a collection with no indexes
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	// Add items
	const item1 = create_test_item('item1', 'cat1');
	const item2 = create_test_item('item2', 'cat2');

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
		indexes: [create_single_index('by_name', (item) => item.name, z.string())],
	});

	// Add items with unique names
	const item1 = create_test_item('apple', 'fruit');
	const item2 = create_test_item('banana', 'fruit');
	const item3 = create_test_item('carrot', 'vegetable');

	collection.add(item1);
	collection.add(item2);
	collection.add(item3);

	// Test lookup by single index
	expect(collection.by_optional<string>('by_name', 'apple')?.id).toBe(item1.id);
	expect(collection.by_optional<string>('by_name', 'banana')?.id).toBe(item2.id);
	expect(collection.by_optional<string>('by_name', 'carrot')?.id).toBe(item3.id);
	expect(collection.by_optional<string>('by_name', 'missing')).toBeUndefined();

	// Test the non-optional version that throws
	expect(() => collection.by<string>('by_name', 'missing')).toThrow();
	expect(collection.by<string>('by_name', 'apple').id).toBe(item1.id);

	// Test query method
	expect(collection.query<Test_Item, string>('by_name', 'apple').id).toBe(item1.id);

	// Test index update on removal
	collection.remove(item2.id);
	expect(collection.by_optional<string>('by_name', 'banana')).toBeUndefined();
	expect(collection.size).toBe(2);
});

test('Indexed_Collection - multi index operations', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [create_multi_index('by_category', (item) => item.category, z.string())],
	});

	// Add items with shared categories
	const item1 = create_test_item('apple', 'fruit');
	const item2 = create_test_item('banana', 'fruit');
	const item3 = create_test_item('carrot', 'vegetable');
	const item4 = create_test_item('lettuce', 'vegetable');

	collection.add(item1);
	collection.add(item2);
	collection.add(item3);
	collection.add(item4);

	// Test multi-index lookup
	expect(collection.where<string>('by_category', 'fruit')).toHaveLength(2);
	const fruit_items = collection.where<string>('by_category', 'fruit');
	expect(fruit_items.some((item) => item.id === item1.id)).toBe(true);
	expect(fruit_items.some((item) => item.id === item2.id)).toBe(true);

	expect(collection.where<string>('by_category', 'vegetable')).toHaveLength(2);
	const vegetable_items = collection.where<string>('by_category', 'vegetable');
	expect(vegetable_items.some((item) => item.id === item3.id)).toBe(true);
	expect(vegetable_items.some((item) => item.id === item4.id)).toBe(true);

	// Test first/latest with limit
	expect(collection.first<string>('by_category', 'fruit', 1)).toHaveLength(1);
	expect(collection.first<string>('by_category', 'fruit', 1)[0].id).toBe(item1.id);
	expect(collection.latest<string>('by_category', 'vegetable', 1)).toHaveLength(1);
	expect(collection.latest<string>('by_category', 'vegetable', 1)[0].id).toBe(item4.id);

	// Test index update on removal
	collection.remove(item1.id);
	expect(collection.where<string>('by_category', 'fruit')).toHaveLength(1);
	expect(collection.where<string>('by_category', 'fruit')[0].id).toBe(item2.id);
});

test('Indexed_Collection - derived index operations', () => {
	const item_schema = z.custom<Test_Item>((val) => val && typeof val === 'object' && 'id' in val);
	const item_array_schema = z.array(item_schema);

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'high_priority',
				type: 'derived',
				compute: (collection) => collection.all.filter((item) => item.priority > 5),
				output_schema: item_array_schema,
				input_schema: z.void(),
				matches: (item) => item.priority > 5,
				on_add: (items, item) => {
					if (item.priority > 5) {
						items.push(item);
						// Keep sorted by priority (highest first)
						items.sort((a, b) => b.priority - a.priority);
					}
					return items;
				},
				on_remove: (items, item) => {
					const index = items.findIndex((i: Test_Item) => i.id === item.id);
					if (index !== -1) {
						items.splice(index, 1);
					}
					return items;
				},
			},
		],
	});

	// Add items with various priorities
	const item1 = create_test_item('task1', 'work', [], 8);
	const item2 = create_test_item('task2', 'home', [], 3);
	const item3 = create_test_item('task3', 'work', [], 10);
	const item4 = create_test_item('task4', 'home', [], 6);

	collection.add(item1);
	collection.add(item2);
	collection.add(item3);
	collection.add(item4);

	// Check derived index
	const high_priority = collection.get_derived('high_priority');
	expect(high_priority).toHaveLength(3);
	// Compare by ID instead of reference
	expect(high_priority[0].id).toBe(item3.id); // Highest priority first
	expect(high_priority[1].id).toBe(item1.id);
	expect(high_priority[2].id).toBe(item4.id);
	expect(high_priority.some((item) => item.id === item2.id)).toBe(false); // Low priority excluded

	// Test direct access via get_index
	const high_priority_via_index = collection.get_index('high_priority');
	expect(high_priority_via_index).toEqual(high_priority);

	// Test incremental update
	const item5 = create_test_item('task5', 'work', [], 9);
	collection.add(item5);

	const updated_high_priority = collection.get_derived('high_priority');
	expect(updated_high_priority).toHaveLength(4);
	expect(updated_high_priority[0].id).toBe(item3.id); // 10
	expect(updated_high_priority[1].id).toBe(item5.id); // 9
	expect(updated_high_priority[2].id).toBe(item1.id); // 8
	expect(updated_high_priority[3].id).toBe(item4.id); // 6

	// Test removal from derived index
	collection.remove(item3.id);
	const after_remove = collection.get_derived('high_priority');
	expect(after_remove).toHaveLength(3);
	expect(after_remove[0].id).toBe(item5.id); // Now highest priority
});

test('Indexed_Collection - combined indexing strategies', () => {
	const item_schema = z.custom<Test_Item>((val) => val && typeof val === 'object' && 'id' in val);
	const item_array_schema = z.array(item_schema);

	// Create strongly typed map schemas to ensure proper typing in callbacks
	const name_map_schema = z.custom<SvelteMap<string, Test_Item>>((val) => val instanceof SvelteMap);
	const category_map_schema = z.custom<SvelteMap<string, Array<Test_Item>>>(
		(val) => val instanceof SvelteMap,
	);
	const tag_map_schema = z.custom<SvelteMap<string, Array<Test_Item>>>(
		(val) => val instanceof SvelteMap,
	);

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'by_name',
				type: 'single',
				extractor: (item) => item.name,
				input_schema: z.string(),
				output_schema: name_map_schema,
				compute: (collection) => {
					const map: SvelteMap<string, Test_Item> = new SvelteMap();
					for (const item of collection.all) {
						map.set(item.name, item);
					}
					return map;
				},
				on_add: (map, item) => {
					map.set(item.name, item);
					return map;
				},
				on_remove: (map, item) => {
					if (map.get(item.name) === item) {
						map.delete(item.name);
					}
					return map;
				},
			},
			{
				key: 'by_category',
				type: 'multi',
				extractor: (item) => item.category,
				input_schema: z.string(),
				output_schema: category_map_schema,
				compute: (collection) => {
					const map: SvelteMap<string, Array<Test_Item>> = new SvelteMap();
					for (const item of collection.all) {
						const items = map.get(item.category) || [];
						items.push(item);
						map.set(item.category, items);
					}
					return map;
				},
				on_add: (map, item) => {
					const items = map.get(item.category) || [];
					items.push(item);
					map.set(item.category, items);
					return map;
				},
				on_remove: (map, item) => {
					const items = map.get(item.category);
					if (items) {
						const updated = items.filter((i: Test_Item) => i.id !== item.id);
						if (updated.length === 0) {
							map.delete(item.category);
						} else {
							map.set(item.category, updated);
						}
					}
					return map;
				},
			},
			{
				key: 'by_tag',
				type: 'multi',
				extractor: (item) => item.tags[0],
				input_schema: z.string(),
				output_schema: tag_map_schema,
				compute: (collection) => {
					const map: SvelteMap<string, Array<Test_Item>> = new SvelteMap();
					for (const item of collection.all) {
						if (item.tags[0]) {
							const items = map.get(item.tags[0]) || [];
							items.push(item);
							map.set(item.tags[0], items);
						}
					}
					return map;
				},
				on_add: (map, item) => {
					if (item.tags[0]) {
						const items = map.get(item.tags[0]) || [];
						items.push(item);
						map.set(item.tags[0], items);
					}
					return map;
				},
				on_remove: (map, item) => {
					if (item.tags[0]) {
						const items = map.get(item.tags[0]);
						if (items) {
							const updated = items.filter((i: Test_Item) => i.id !== item.id);
							if (updated.length === 0) {
								map.delete(item.tags[0]);
							} else {
								map.set(item.tags[0], updated);
							}
						}
					}
					return map;
				},
			},
			{
				key: 'recent_high_priority',
				type: 'derived',
				compute: (collection) => {
					return collection.all
						.filter((item) => item.priority >= 8)
						.sort((a, b) => b.created.getTime() - a.created.getTime());
				},
				input_schema: z.void(),
				output_schema: item_array_schema,
				matches: (item) => item.priority >= 8,
				// Add on_add handler to correctly populate the index
				on_add: (items, item) => {
					if (item.priority >= 8) {
						items.push(item);
						// Sort by creation date (newest first)
						items.sort((a, b) => b.created.getTime() - a.created.getTime());
					}
					return items;
				},
			},
		],
	});

	// Create items with a mix of properties
	const item1 = create_test_item('apple', 'fruit', ['red', 'sweet'], 9);
	const item2 = create_test_item('banana', 'fruit', ['yellow', 'sweet'], 7);
	const item3 = create_test_item('carrot', 'vegetable', ['orange', 'crunchy'], 3);
	const item4 = create_test_item('dragonfruit', 'fruit', ['pink', 'exotic'], 10);

	collection.add_many([item1, item2, item3, item4]);

	// Test single index lookup
	expect(collection.by_optional<string>('by_name', 'apple')?.id).toBe(item1.id);

	// Test multi index lookup
	expect(collection.where<string>('by_category', 'fruit')).toHaveLength(3);
	expect(collection.where<string>('by_tag', 'red').some((item) => item.id === item1.id)).toBe(true);

	// Test derived index
	const high_priority = collection.get_derived('recent_high_priority');
	expect(high_priority).toHaveLength(2);
	expect(high_priority.some((item) => item.id === item1.id)).toBe(true);
	expect(high_priority.some((item) => item.id === item4.id)).toBe(true);
	expect(high_priority.some((item) => item.id === item2.id)).toBe(false); // Priority 7 is too low
});

test('Indexed_Collection - add_first and ordering', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	const item1 = create_test_item('first', 'test');
	const item2 = create_test_item('second', 'test');
	const item3 = create_test_item('third', 'test');

	// Add in specific order
	collection.add(item1);
	collection.add_first(item2);
	collection.add(item3);

	// Check ordering using ID comparison
	expect(collection.all[0].id).toBe(item2.id);
	expect(collection.all[1].id).toBe(item1.id);
	expect(collection.all[2].id).toBe(item3.id);

	// Test insert_at
	const item4 = create_test_item('inserted', 'test');
	collection.insert_at(item4, 1);

	expect(collection.all[0].id).toBe(item2.id);
	expect(collection.all[1].id).toBe(item4.id);
	expect(collection.all[2].id).toBe(item1.id);
	expect(collection.all[3].id).toBe(item3.id);
});

test('Indexed_Collection - reorder items', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	const items = [
		create_test_item('a', 'test'),
		create_test_item('b', 'test'),
		create_test_item('c', 'test'),
		create_test_item('d', 'test'),
	];

	collection.add_many(items);

	// Initial order: a, b, c, d
	expect(collection.all[0].name).toBe('a');
	expect(collection.all[3].name).toBe('d');

	// Move 'a' to position 2
	collection.reorder(0, 2);

	// New order should be: b, c, a, d
	expect(collection.all[0].name).toBe('b');
	expect(collection.all[1].name).toBe('c');
	expect(collection.all[2].name).toBe('a');
	expect(collection.all[3].name).toBe('d');
});

test('Indexed_Collection - function indexes', () => {
	// Define schema for a function that takes a string and returns an array of Test_Item
	const function_schema = z.function().args(z.string()).returns(z.array(z.custom<Test_Item>()));

	// Test a function-based index
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'by_priority_rank',
				compute: () => {
					// Create a function that returns items by priority level
					return (priority_level: string) => {
						if (priority_level === 'high') {
							return collection.all.filter((item) => item.priority >= 8);
						} else if (priority_level === 'medium') {
							return collection.all.filter((item) => item.priority >= 4 && item.priority < 8);
						} else {
							return collection.all.filter((item) => item.priority < 4);
						}
					};
				},
				input_schema: z.string(),
				output_schema: function_schema,
				on_add: (fn) => fn, // Just keep the function as is
				on_remove: (fn) => fn, // Just keep the function as is
			},
		],
	});

	// Add items with different priorities
	collection.add(create_test_item('high1', 'test', [], 10));
	collection.add(create_test_item('high2', 'test', [], 8));
	collection.add(create_test_item('medium1', 'test', [], 7));
	collection.add(create_test_item('medium2', 'test', [], 5));
	collection.add(create_test_item('low1', 'test', [], 3));
	collection.add(create_test_item('low2', 'test', [], 1));

	// The index is a function that can be queried
	const priority_fn = collection.get_index<(level: string) => Array<Test_Item>>('by_priority_rank');

	// Test function index queries
	expect(priority_fn('high')).toHaveLength(2);
	expect(priority_fn('medium')).toHaveLength(2);
	expect(priority_fn('low')).toHaveLength(2);

	// Test using the query method
	expect(collection.query<Array<Test_Item>, string>('by_priority_rank', 'high')).toHaveLength(2);
	expect(collection.query<Array<Test_Item>, string>('by_priority_rank', 'medium')).toHaveLength(2);
	expect(collection.query<Array<Test_Item>, string>('by_priority_rank', 'low')).toHaveLength(2);
});

test('Indexed_Collection - complex data structures', () => {
	// Define schema for stats object
	const stats_schema = z.object({
		count: z.number(),
		average_priority: z.number(),
		categories: z.custom<Set<string>>((val) => val instanceof Set),
	});

	// Test an index that produces a complex data structure
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'stats',
				compute: (collection) => {
					const items = collection.all;
					return {
						count: items.length,
						average_priority:
							items.reduce((sum, item) => sum + item.priority, 0) / (items.length || 1),
						categories: new Set(items.map((item) => item.category)),
					};
				},
				input_schema: z.void(),
				output_schema: stats_schema,
				on_add: (stats, item) => {
					stats.count++;
					stats.average_priority =
						(stats.average_priority * (stats.count - 1) + item.priority) / stats.count;
					stats.categories.add(item.category);
					return stats;
				},
				on_remove: (stats, item) => {
					stats.count--;
					if (stats.count === 0) {
						stats.average_priority = 0;
					} else {
						stats.average_priority =
							(stats.average_priority * (stats.count + 1) - item.priority) / stats.count;
					}

					// Rebuild categories set if needed (we don't know if other items use this category)
					const all_categories = new Set(
						collection.all.filter((i) => i.id !== item.id).map((i) => i.category),
					);
					stats.categories = all_categories;

					return stats;
				},
			},
		],
	});

	// Add items
	collection.add(create_test_item('item1', 'category1', [], 10));
	collection.add(create_test_item('item2', 'category2', [], 20));

	// Test complex index structure
	const stats = collection.get_index<{
		count: number;
		average_priority: number;
		categories: Set<string>;
	}>('stats');

	expect(stats.count).toBe(2);
	expect(stats.average_priority).toBe(15);
	expect(stats.categories.size).toBe(2);
	expect(stats.categories.has('category1')).toBe(true);

	// Test updating the complex structure
	collection.add(create_test_item('item3', 'category1', [], 30));

	expect(stats.count).toBe(3);
	expect(stats.average_priority).toBe(20);
	expect(stats.categories.size).toBe(2);
});
