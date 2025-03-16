import {test, expect} from 'vitest';
import {Indexed_Collection, Index_Type} from '$lib/indexed_collection.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';

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
	expect(collection.all).toContain(item1);
	expect(collection.all).toContain(item2);

	// Test retrieval by ID
	expect(collection.get(item1.id)).toBe(item1);

	// Test removal
	expect(collection.remove(item1.id)).toBe(true);
	expect(collection.size).toBe(1);
	expect(collection.get(item1.id)).toBeUndefined();
	expect(collection.get(item2.id)).toBe(item2);
});

test('Indexed_Collection - single index operations', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'by_name',
				type: Index_Type.SINGLE,
				extractor: (item) => item.name,
			},
		],
	});

	// Add items with unique names
	const item1 = create_test_item('apple', 'fruit');
	const item2 = create_test_item('banana', 'fruit');
	const item3 = create_test_item('carrot', 'vegetable');

	collection.add(item1);
	collection.add(item2);
	collection.add(item3);

	// Test lookup by single index
	expect(collection.by_optional('by_name', 'apple')).toBe(item1);
	expect(collection.by_optional('by_name', 'banana')).toBe(item2);
	expect(collection.by_optional('by_name', 'carrot')).toBe(item3);
	expect(collection.by_optional('by_name', 'missing')).toBeUndefined();

	// Test the non-optional version that throws
	expect(() => collection.by('by_name', 'missing')).toThrow();
	expect(collection.by('by_name', 'apple')).toBe(item1);

	// Test index update on removal
	collection.remove(item2.id);
	expect(collection.by_optional('by_name', 'banana')).toBeUndefined();
	expect(collection.size).toBe(2);
});

test('Indexed_Collection - multi index operations', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'by_category',
				type: Index_Type.MULTI,
				extractor: (item) => item.category,
			},
		],
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
	expect(collection.where('by_category', 'fruit')).toHaveLength(2);
	expect(collection.where('by_category', 'fruit')).toContainEqual(item1);
	expect(collection.where('by_category', 'fruit')).toContainEqual(item2);
	expect(collection.where('by_category', 'vegetable')).toHaveLength(2);
	expect(collection.where('by_category', 'vegetable')).toContainEqual(item3);
	expect(collection.where('by_category', 'vegetable')).toContainEqual(item4);

	// Test first/latest with limit
	expect(collection.first('by_category', 'fruit', 1)).toHaveLength(1);
	expect(collection.first('by_category', 'fruit', 1)[0]).toBe(item1);
	expect(collection.latest('by_category', 'vegetable', 1)).toHaveLength(1);
	expect(collection.latest('by_category', 'vegetable', 1)[0]).toBe(item4);

	// Test index update on removal
	collection.remove(item1.id);
	expect(collection.where('by_category', 'fruit')).toHaveLength(1);
	expect(collection.where('by_category', 'fruit')[0]).toBe(item2);
});

test('Indexed_Collection - derived index operations', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'high_priority',
				type: Index_Type.DERIVED,
				compute: (collection) => collection.all.filter((item) => item.priority > 5),
				matches: (item) => item.priority > 5,
				on_add: (items, item) => {
					if (item.priority > 5) {
						items.push(item);
						// Keep sorted by priority (highest first)
						items.sort((a, b) => b.priority - a.priority);
					}
				},
				on_remove: (items, item) => {
					const index = items.findIndex((i) => i.id === item.id);
					if (index !== -1) {
						items.splice(index, 1);
					}
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
	expect(high_priority[0]).toBe(item3); // Highest priority first
	expect(high_priority[1]).toBe(item1);
	expect(high_priority[2]).toBe(item4);
	expect(high_priority).not.toContain(item2); // Low priority excluded

	// Test incremental update
	const item5 = create_test_item('task5', 'work', [], 9);
	collection.add(item5);

	const updated_high_priority = collection.get_derived('high_priority');
	expect(updated_high_priority).toHaveLength(4);
	expect(updated_high_priority[0]).toBe(item3); // 10
	expect(updated_high_priority[1]).toBe(item5); // 9
	expect(updated_high_priority[2]).toBe(item1); // 8
	expect(updated_high_priority[3]).toBe(item4); // 6

	// Test removal from derived index
	collection.remove(item3.id);
	const after_remove = collection.get_derived('high_priority');
	expect(after_remove).toHaveLength(3);
	expect(after_remove[0]).toBe(item5); // Now highest priority
});

test('Indexed_Collection - combined indexing strategies', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'by_name',
				type: Index_Type.SINGLE,
				extractor: (item) => item.name,
			},
			{
				key: 'by_category',
				type: Index_Type.MULTI,
				extractor: (item) => item.category,
			},
			{
				key: 'by_tag',
				type: Index_Type.MULTI,
				extractor: (item) => item.tags[0], // Just the first tag
			},
			{
				key: 'recent_high_priority',
				type: Index_Type.DERIVED,
				compute: (collection) => {
					return collection.all
						.filter((item) => item.priority >= 8)
						.sort((a, b) => b.created.getTime() - a.created.getTime());
				},
				matches: (item) => item.priority >= 8,
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
	expect(collection.by_optional('by_name', 'apple')).toBe(item1);

	// Test multi index lookup
	expect(collection.where('by_category', 'fruit')).toHaveLength(3);
	expect(collection.where('by_tag', 'red')).toContainEqual(item1);

	// Test derived index
	const high_priority = collection.get_derived('recent_high_priority');
	expect(high_priority).toHaveLength(2);
	expect(high_priority).toContain(item1);
	expect(high_priority).toContain(item4);
	expect(high_priority).not.toContain(item2); // Priority 7 is too low
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

	// Check ordering
	expect(collection.all[0]).toBe(item2);
	expect(collection.all[1]).toBe(item1);
	expect(collection.all[2]).toBe(item3);

	// Test insert_at
	const item4 = create_test_item('inserted', 'test');
	collection.insert_at(item4, 1);

	expect(collection.all[0]).toBe(item2);
	expect(collection.all[1]).toBe(item4);
	expect(collection.all[2]).toBe(item1);
	expect(collection.all[3]).toBe(item3);
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

test('Indexed_Collection - remove_many items efficiently', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'by_category',
				type: Index_Type.MULTI,
				extractor: (item) => item.category,
			},
		],
	});

	// Add items
	const items = [
		create_test_item('a', 'food'),
		create_test_item('b', 'drink'),
		create_test_item('c', 'food'),
		create_test_item('d', 'drink'),
		create_test_item('e', 'other'),
	];

	collection.add_many(items);
	expect(collection.size).toBe(5);

	// Remove multiple items
	const removed = collection.remove_many([items[0].id, items[3].id]);

	// Check removal count
	expect(removed).toBe(2);
	expect(collection.size).toBe(3);

	// Check that indexes are updated
	expect(collection.where('by_category', 'food')).toHaveLength(1);
	expect(collection.where('by_category', 'food')[0]).toBe(items[2]);
	expect(collection.where('by_category', 'drink')).toHaveLength(1);
	expect(collection.where('by_category', 'drink')[0]).toBe(items[1]);
});

test('Indexed_Collection - clear collection', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [
			{
				key: 'by_category',
				type: Index_Type.MULTI,
				extractor: (item) => item.category,
			},
			{
				key: 'by_name',
				type: Index_Type.SINGLE,
				extractor: (item) => item.name,
			},
			{
				key: 'high_priority',
				type: Index_Type.DERIVED,
				compute: (collection) => {
					// Explicitly filter only items with priority > 5
					return collection.all.filter((item) => item.priority > 5);
				},
				// Add matches function for incremental updates
				matches: (item) => item.priority > 5,
			},
		],
	});

	// Add items
	const items = [
		create_test_item('a', 'food', [], 10), // high priority
		create_test_item('b', 'drink', [], 3), // NOT high priority
		create_test_item('c', 'food', [], 8), // high priority
	];

	collection.add_many(items);

	expect(collection.size).toBe(3);
	expect(collection.where('by_category', 'food')).toHaveLength(2);

	// Check the high priority items
	const high_priority_items = collection.get_derived('high_priority');
	expect(high_priority_items.length).toBe(2);
	expect(high_priority_items.map((i) => i.name).sort()).toEqual(['a', 'c']);

	// Clear the collection
	collection.clear();

	// Verify all cleared
	expect(collection.size).toBe(0);
	expect(collection.all).toHaveLength(0);
	expect(collection.where('by_category', 'food')).toHaveLength(0);
	expect(collection.get_derived('high_priority')).toHaveLength(0);
	expect(collection.by_optional('by_name', 'a')).toBeUndefined();
});
