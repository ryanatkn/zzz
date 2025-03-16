// @vitest-environment jsdom

import {test, expect} from 'vitest';
import {Indexed_Collection, type Indexed_Item} from '$lib/indexed_collection.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';

// Define uuid constants for deterministic testing
const uuid_1 = Uuid.parse(undefined);
const uuid_2 = Uuid.parse(undefined);
const uuid_3 = Uuid.parse(undefined);
const uuid_4 = Uuid.parse(undefined);
const uuid_5 = Uuid.parse(undefined);
const uuid_99 = Uuid.parse(undefined);

// Helper interfaces and fixtures
interface Test_Item extends Indexed_Item {
	id: Uuid;
	name: string;
	category: string;
	tags: Array<string>;
}

const create_test_item = (
	id: Uuid,
	name: string,
	category: string,
	tags: Array<string> = [],
): Test_Item => {
	return {id, name, category, tags};
};

const sample_items: Array<Test_Item> = [
	create_test_item(uuid_1, 'apple', 'fruit', ['red', 'sweet']),
	create_test_item(uuid_2, 'banana', 'fruit', ['yellow']),
	create_test_item(uuid_3, 'carrot', 'vegetable', ['orange']),
	create_test_item(uuid_4, 'daikon', 'vegetable', ['white']),
	create_test_item(uuid_5, 'eggplant', 'vegetable', ['purple']),
];

// Basic initialization tests
test('Indexed_Collection - initializes with empty array by default', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();
	expect(collection.all).toEqual([]);
	expect(collection.size).toBe(0);
});

test('Indexed_Collection - initializes with provided items', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1]],
	});

	expect(collection.all.length).toBe(2);
	expect(collection.by_id.get(uuid_1)).toEqual(sample_items[0]);
	expect(collection.by_id.get(uuid_2)).toEqual(sample_items[1]);
});

test('Indexed_Collection - initializes with configured indexes', () => {
	const collection: Indexed_Collection<Test_Item, 'name' | 'category'> = new Indexed_Collection({
		indexes: [
			{key: 'name', extractor: (item) => item.name},
			{key: 'category', extractor: (item) => item.category, multi: true},
		],
	});

	expect(collection.single_indexes.name).toBeDefined();
	expect(collection.multi_indexes.category).toBeDefined();
});

// Test constructor edge cases
test('Indexed_Collection - initializes with empty options object', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({});

	expect(collection.all).toEqual([]);
	expect(collection.size).toBe(0);
	expect(collection.by_id.size).toBe(0);
});

test('Indexed_Collection - initializes with empty indexes array', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		indexes: [],
	});

	expect(collection.all).toEqual([]);
	expect(collection.single_indexes).toEqual({});
	expect(collection.multi_indexes).toEqual({});
});

test('Indexed_Collection - initializes with multiple indexes of different types', () => {
	const collection: Indexed_Collection<Test_Item, 'name' | 'category' | 'tags'> =
		new Indexed_Collection({
			indexes: [
				{key: 'name', extractor: (item) => item.name},
				{key: 'category', extractor: (item) => item.category, multi: true},
				{key: 'tags', extractor: (item) => item.tags.join(','), multi: true},
			],
		});

	expect(collection.single_indexes.name).toBeDefined();
	expect(collection.multi_indexes.category).toBeDefined();
	expect(collection.multi_indexes.tags).toBeDefined();
});

// Adding and retrieving items
test('Indexed_Collection - add method adds items and updates indexes', () => {
	const collection: Indexed_Collection<Test_Item, 'name' | 'category'> = new Indexed_Collection({
		indexes: [
			{key: 'name', extractor: (item) => item.name},
			{key: 'category', extractor: (item) => item.category, multi: true},
		],
	});

	collection.add(sample_items[0]);
	collection.add(sample_items[1]);

	// Check main array
	expect(collection.all.length).toBe(2);

	// Check primary index
	expect(collection.by_id.get(uuid_1)).toEqual(sample_items[0]);

	// Check single-value index
	expect(collection.single_indexes.name?.get('apple')).toEqual(sample_items[0]);
	expect(collection.single_indexes.name?.get('banana')).toEqual(sample_items[1]);

	// Check multi-value index
	expect(collection.multi_indexes.category?.get('fruit')).toEqual([
		sample_items[0],
		sample_items[1],
	]);

	// Check position index
	expect(collection.position_index.get(uuid_1)).toBe(0);
	expect(collection.position_index.get(uuid_2)).toBe(1);
});

test('Indexed_Collection - add multiple items with various index values', () => {
	const collection: Indexed_Collection<Test_Item, 'name' | 'tags'> = new Indexed_Collection({
		indexes: [
			{key: 'name', extractor: (item) => item.name},
			{key: 'tags', extractor: (item) => item.tags[0], multi: true},
		],
	});

	collection.add(sample_items[0]); // tags: ['red', 'sweet']
	collection.add(sample_items[2]); // tags: ['orange']
	collection.add(sample_items[3]); // tags: ['white']

	// Check single-value index
	expect(collection.single_indexes.name?.size).toBe(3);

	// Check multi-value index with different values
	expect(collection.multi_indexes.tags?.get('red')?.length).toBe(1);
	expect(collection.multi_indexes.tags?.get('orange')?.length).toBe(1);
	expect(collection.multi_indexes.tags?.get('white')?.length).toBe(1);
});

test('Indexed_Collection - add_first method adds items at the beginning', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	collection.add(sample_items[0]);
	collection.add_first(sample_items[1]);

	expect(collection.all[0]).toEqual(sample_items[1]);
	expect(collection.all[1]).toEqual(sample_items[0]);

	// Check that position indexes are updated correctly
	expect(collection.position_index.get(uuid_1)).toBe(1); // moved to position 1
	expect(collection.position_index.get(uuid_2)).toBe(0); // at position 0
});

test('Indexed_Collection - adding items returns the added item', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	const result1 = collection.add(sample_items[0]);
	const result2 = collection.add_first(sample_items[1]);

	expect(result1).toBe(sample_items[0]);
	expect(result2).toBe(sample_items[1]);
});

// Item access and checking
test('Indexed_Collection - get method retrieves items by id', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1]],
	});

	expect(collection.get(uuid_1)).toEqual(sample_items[0]);
	expect(collection.get(uuid_2)).toEqual(sample_items[1]);
	expect(collection.get(uuid_3)).toBeUndefined();
});

test('Indexed_Collection - has method checks if item exists by id', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1]],
	});

	expect(collection.has(uuid_1)).toBe(true);
	expect(collection.has(uuid_3)).toBe(false);
});

// Removing items
test('Indexed_Collection - remove method removes items by id and updates indexes', () => {
	const collection: Indexed_Collection<Test_Item, 'name' | 'category'> = new Indexed_Collection({
		indexes: [
			{key: 'name', extractor: (item) => item.name},
			{key: 'category', extractor: (item) => item.category, multi: true},
		],
		initial_items: [sample_items[0], sample_items[1], sample_items[2]],
	});

	// Check initial position indexes
	expect(collection.position_index.get(uuid_1)).toBe(0);
	expect(collection.position_index.get(uuid_2)).toBe(1);
	expect(collection.position_index.get(uuid_3)).toBe(2);

	const removed = collection.remove(uuid_2);

	expect(removed).toBe(true);
	expect(collection.all.length).toBe(2);
	expect(collection.by_id.has(uuid_2)).toBe(false);
	expect(collection.single_indexes.name?.has('banana')).toBe(false);

	// Verify position indexes were updated
	expect(collection.position_index.has(uuid_2)).toBe(false); // removed item's position should be gone
	expect(collection.position_index.get(uuid_1)).toBe(0); // unchanged
	expect(collection.position_index.get(uuid_3)).toBe(1); // moved up one position

	// Check that the category index was updated properly
	const fruit_items = collection.multi_indexes.category?.get('fruit');
	expect(fruit_items?.length).toBe(1);
	expect(fruit_items?.[0].id).toBe(uuid_1);
});

test('Indexed_Collection - remove method returns false when id not found', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();
	collection.add(sample_items[0]);

	const removed = collection.remove(uuid_99);

	expect(removed).toBe(false);
	expect(collection.all.length).toBe(1);
});

test('Indexed_Collection - remove from empty collection', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	const removed = collection.remove(uuid_1);

	expect(removed).toBe(false);
});

test('Indexed_Collection - remove affects multi-index with shared values', () => {
	// Create items that share a tag
	const shared_tag = 'shared';
	const item1 = create_test_item(uuid_1, 'item1', 'category1', [shared_tag]);
	const item2 = create_test_item(uuid_2, 'item2', 'category2', [shared_tag]);

	const collection: Indexed_Collection<Test_Item, 'tags'> = new Indexed_Collection({
		indexes: [{key: 'tags', extractor: (item) => item.tags[0], multi: true}],
		initial_items: [item1, item2],
	});

	// Both items should share the same tag index
	expect(collection.multi_indexes.tags?.get(shared_tag)?.length).toBe(2);

	// Remove one item
	collection.remove(uuid_1);

	// Tag index should still exist with one item
	expect(collection.multi_indexes.tags?.get(shared_tag)?.length).toBe(1);
	expect(collection.multi_indexes.tags?.get(shared_tag)?.[0].id).toBe(uuid_2);
});

// Reordering tests
test('Indexed_Collection - reorder method changes item order', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1], sample_items[2]],
	});

	// Check initial position indexes
	expect(collection.position_index.get(uuid_1)).toBe(0);
	expect(collection.position_index.get(uuid_2)).toBe(1);
	expect(collection.position_index.get(uuid_3)).toBe(2);

	collection.reorder(0, 2);

	expect(collection.all[0].id).toBe(uuid_2);
	expect(collection.all[1].id).toBe(uuid_3);
	expect(collection.all[2].id).toBe(uuid_1);

	// Verify position indexes were updated after reordering
	expect(collection.position_index.get(uuid_1)).toBe(2); // moved to end
	expect(collection.position_index.get(uuid_2)).toBe(0); // moved to beginning
	expect(collection.position_index.get(uuid_3)).toBe(1); // moved to middle
});

test('Indexed_Collection - reorder does nothing when indexes are invalid or equal', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1], sample_items[2]],
	});

	// Same index
	collection.reorder(1, 1);
	expect(collection.all[1].id).toBe(uuid_2);

	// Negative index
	collection.reorder(-1, 1);
	expect(collection.all[0].id).toBe(uuid_1);
	expect(collection.all[1].id).toBe(uuid_2);

	// Out of bounds index
	collection.reorder(0, 10);
	expect(collection.all[0].id).toBe(uuid_1);
});

// Multi-index features
test('Indexed_Collection - handles multi-index removal correctly when last item removed', () => {
	const collection: Indexed_Collection<Test_Item, 'category'> = new Indexed_Collection({
		indexes: [{key: 'category', extractor: (item) => item.category, multi: true}],
		initial_items: [sample_items[0]],
	});

	collection.remove(uuid_1);

	expect(collection.multi_indexes.category?.has('fruit')).toBe(false);
});

test('Indexed_Collection - correctly maintains multi-index when some items remain', () => {
	const collection: Indexed_Collection<Test_Item, 'category'> = new Indexed_Collection({
		indexes: [{key: 'category', extractor: (item) => item.category, multi: true}],
		initial_items: [sample_items[0], sample_items[1], sample_items[2]],
	});

	collection.remove(uuid_1);

	const fruit_items = collection.multi_indexes.category?.get('fruit');
	expect(fruit_items?.length).toBe(1);
	expect(fruit_items?.[0].id).toBe(uuid_2);

	const vegetable_items = collection.multi_indexes.category?.get('vegetable');
	expect(vegetable_items?.length).toBe(1);
	expect(vegetable_items?.[0].id).toBe(uuid_3);
});

// Clearing tests
test('Indexed_Collection - clear method resets the collection', () => {
	const collection: Indexed_Collection<Test_Item, 'name' | 'category'> = new Indexed_Collection({
		indexes: [
			{key: 'name', extractor: (item) => item.name},
			{key: 'category', extractor: (item) => item.category, multi: true},
		],
		initial_items: [sample_items[0], sample_items[1], sample_items[2]],
	});

	// Verify position indexes exist before clearing
	expect(collection.position_index.size).toBe(3);
	expect(collection.position_index.get(uuid_1)).toBe(0);

	collection.clear();

	expect(collection.all.length).toBe(0);
	expect(collection.by_id.size).toBe(0);
	expect(collection.position_index.size).toBe(0); // Position index should be cleared
	expect(collection.single_indexes.name?.size).toBe(0);
	expect(collection.multi_indexes.category?.size).toBe(0);
});

// Edge cases and special conditions
test('Indexed_Collection - handles null/undefined index values', () => {
	interface Item_With_Optional extends Indexed_Item {
		id: Uuid;
		optional_field?: string;
	}

	const collection: Indexed_Collection<Item_With_Optional, 'optional_field'> =
		new Indexed_Collection<Item_With_Optional, 'optional_field'>({
			indexes: [{key: 'optional_field', extractor: (item) => item.optional_field}],
		});

	const item1 = {id: uuid_1, optional_field: 'value'};
	const item2 = {id: uuid_2}; // optional_field is undefined

	collection.add(item1);
	collection.add(item2);

	expect(collection.all.length).toBe(2);
	expect(collection.single_indexes.optional_field?.get('value')).toEqual(item1);
	// The undefined value should not be added to the index
	expect(collection.single_indexes.optional_field?.has(undefined as any)).toBe(false);
});

test('Indexed_Collection - null/undefined extractor values are handled consistently', () => {
	interface Nullable_Item extends Indexed_Item {
		id: Uuid;
		nullable_value: string | null | undefined;
	}

	const collection: Indexed_Collection<Nullable_Item, 'nullable'> = new Indexed_Collection({
		indexes: [{key: 'nullable', extractor: (item) => item.nullable_value}],
	});

	const item1 = {id: uuid_1, nullable_value: 'value'};
	const item2 = {id: uuid_2, nullable_value: null};
	const item3 = {id: uuid_3, nullable_value: undefined};

	collection.add(item1);
	collection.add(item2);
	collection.add(item3);

	expect(collection.all.length).toBe(3);
	expect(collection.single_indexes.nullable?.get('value')).toEqual(item1);

	// Null and undefined values should not be added to the index
	expect(collection.single_indexes.nullable?.has(null as any)).toBe(false);
	expect(collection.single_indexes.nullable?.has(undefined as any)).toBe(false);

	// But the items should still be retrievable by ID
	expect(collection.get(uuid_2)).toBe(item2);
	expect(collection.get(uuid_3)).toBe(item3);
});

// JSON and serialization
test('Indexed_Collection - toJSON returns the array snapshot', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1]],
	});

	const json_result = collection.toJSON();
	expect(json_result).toEqual([sample_items[0], sample_items[1]]);
});

test('Indexed_Collection - toJSON returns a snapshot that matches current state', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: sample_items.slice(0, 3),
	});

	const snapshot = collection.toJSON();

	expect(snapshot).toEqual(sample_items.slice(0, 3));

	// Modify the collection after taking a snapshot
	collection.remove(uuid_1);

	// The snapshot should not be affected by the removal
	expect(snapshot).toEqual(sample_items.slice(0, 3));

	// A new snapshot should reflect the current state
	expect(collection.toJSON()).toEqual([sample_items[1], sample_items[2]]);
});

// Performance considerations
test('Indexed_Collection - handles large number of items efficiently', () => {
	const collection: Indexed_Collection<Test_Item, 'category'> = new Indexed_Collection({
		indexes: [{key: 'category', extractor: (item) => item.category, multi: true}],
	});

	const many_items: Array<Test_Item> = [];
	for (let i = 0; i < 1000; i++) {
		const id = `00000000-0000-0000-0000-${i.toString().padStart(12, '0')}` as Uuid;
		const category = i % 10 === 0 ? 'special' : 'normal';
		many_items.push(create_test_item(id, `item${i}`, category, []));
	}

	// Adding many items should not throw errors
	for (const item of many_items) {
		collection.add(item);
	}

	expect(collection.size).toBe(1000);

	// Index should contain correct groupings
	expect(collection.multi_indexes.category?.get('special')?.length).toBe(100); // Every 10th item
	expect(collection.multi_indexes.category?.get('normal')?.length).toBe(900);
});

// Index configuration tests
test('Indexed_Collection - index configuration handles varying types', () => {
	interface Complex_Item extends Indexed_Item {
		id: Uuid;
		number_value: number;
		boolean_value: boolean;
		date_value: Date;
	}

	const item1: Complex_Item = {
		id: uuid_1,
		number_value: 42,
		boolean_value: true,
		date_value: new Date('2023-01-01'),
	};

	const item2: Complex_Item = {
		id: uuid_2,
		number_value: 99,
		boolean_value: false,
		date_value: new Date('2023-02-01'),
	};

	const collection: Indexed_Collection<Complex_Item, 'number' | 'boolean' | 'date'> =
		new Indexed_Collection({
			indexes: [
				{key: 'number', extractor: (item) => item.number_value},
				{key: 'boolean', extractor: (item) => item.boolean_value},
				{key: 'date', extractor: (item) => item.date_value.toISOString()},
			],
			initial_items: [item1, item2],
		});

	expect(collection.single_indexes.number?.get(42)).toBe(item1);
	expect(collection.single_indexes.boolean?.get(true)).toBe(item1);
	expect(collection.single_indexes.date?.get(new Date('2023-01-01').toISOString())).toBe(item1);
});

// Serialization and reconstruction
test('Indexed_Collection - can be serialized and deserialized', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1]],
	});

	// Convert to JSON string
	const json_string = JSON.stringify(collection);

	// Parse back from JSON
	const parsed_data = JSON.parse(json_string);

	// Create a new collection with the parsed data
	const new_collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: parsed_data,
	});

	// The new collection should have the same items
	expect(new_collection.size).toBe(2);
	expect(new_collection.get(uuid_1)).toEqual(sample_items[0]);
	expect(new_collection.get(uuid_2)).toEqual(sample_items[1]);
});

// Test where method with single value indexes
test('Indexed_Collection - where method works with single-value indexes', () => {
	const collection: Indexed_Collection<Test_Item, 'name'> = new Indexed_Collection({
		indexes: [{key: 'name', extractor: (item) => item.name}],
		initial_items: sample_items,
	});

	// Single value indexes should still return arrays for consistency
	const apples = collection.where('name', 'apple');
	expect(apples).toBeInstanceOf(Array);
	expect(apples.length).toBe(1);
	expect(apples[0].name).toBe('apple');

	// Non-existent values should return empty arrays
	const oranges = collection.where('name', 'orange');
	expect(oranges).toBeInstanceOf(Array);
	expect(oranges.length).toBe(0);
});

// Test the ordering of add vs add_first with multi-indexes
test('Indexed_Collection - multi-indexes preserve insertion order', () => {
	const collection: Indexed_Collection<Test_Item, 'category'> = new Indexed_Collection({
		indexes: [{key: 'category', extractor: (item) => item.category, multi: true}],
	});

	// Add items in specific order
	collection.add(sample_items[0]); // apple (fruit)
	collection.add(sample_items[1]); // banana (fruit)

	// Add a fruit at the beginning
	const first_fruit = create_test_item(uuid_99, 'first_fruit', 'fruit', []);
	collection.add_first(first_fruit);

	// Check multi-index order
	const fruits = collection.where('category', 'fruit');
	expect(fruits.length).toBe(3);
	expect(fruits[0].name).toBe('first_fruit'); // Should be first
	expect(fruits[1].name).toBe('apple');
	expect(fruits[2].name).toBe('banana');
});

// Test first and latest with empty indexes
test('Indexed_Collection - first/latest methods handle empty results gracefully', () => {
	const collection: Indexed_Collection<Test_Item, 'category'> = new Indexed_Collection({
		indexes: [{key: 'category', extractor: (item) => item.category, multi: true}],
	});

	const empty_first = collection.first('category', 'nonexistent', 5);
	const empty_latest = collection.latest('category', 'nonexistent', 5);

	expect(empty_first).toBeInstanceOf(Array);
	expect(empty_first.length).toBe(0);
	expect(empty_latest).toBeInstanceOf(Array);
	expect(empty_latest.length).toBe(0);
});

// Test behavior with circular references
test('Indexed_Collection - handles circular references in items', () => {
	interface Recursive_Item extends Indexed_Item {
		id: Uuid;
		name: string;
		parent_id?: Uuid;
		children: Array<Uuid>;
	}

	const item1: Recursive_Item = {id: uuid_1, name: 'parent', children: []};
	const item2: Recursive_Item = {id: uuid_2, name: 'child', parent_id: uuid_1, children: []};

	// Add child ID to parent's children array
	item1.children.push(item2.id);
	// Create circular reference
	item2.children.push(item1.id);

	const collection: Indexed_Collection<Recursive_Item, 'name'> = new Indexed_Collection({
		indexes: [{key: 'name', extractor: (item) => item.name}],
		initial_items: [item1, item2],
	});

	// Should be able to serialize and get items without issues
	expect(collection.size).toBe(2);

	// JSON serialization should work without circular reference issues
	expect(() => JSON.stringify(collection)).not.toThrow();

	// Related items should work with property access for direct IDs
	const parent_to_child = collection.related([item1], 'children[0]');
	const child_to_parent = collection.related([item2], 'parent_id');

	expect(parent_to_child.length).toBe(1);
	expect(parent_to_child[0].name).toBe('child');
	expect(child_to_parent.length).toBe(1);
	expect(child_to_parent[0].name).toBe('parent');
});

// Test handling of duplicate keys in multi-indexes
test('Indexed_Collection - handles duplicate values in multi-indexes', () => {
	const collection: Indexed_Collection<Test_Item, 'tag'> = new Indexed_Collection({
		indexes: [
			// Use a single tag extractor that returns the first tag
			{key: 'tag', extractor: (item) => item.tags[0], multi: true},
		],
	});

	// Create items with duplicate tag values
	const item1 = create_test_item(uuid_1, 'item1', 'cat1', ['shared', 'unique1']);
	const item2 = create_test_item(uuid_2, 'item2', 'cat2', ['shared', 'unique2']);
	const item3 = create_test_item(uuid_3, 'item3', 'cat3', ['shared', 'unique3']);

	collection.add(item1);
	collection.add(item2);
	collection.add(item3);

	// The shared tag should contain all three items
	const shared_items = collection.where('tag', 'shared');
	expect(shared_items.length).toBe(3);

	// Remove one item
	collection.remove(uuid_2);

	// The shared tag should now contain two items
	const remaining_shared = collection.where('tag', 'shared');
	expect(remaining_shared.length).toBe(2);
	expect(remaining_shared[0].id).toBe(uuid_1);
	expect(remaining_shared[1].id).toBe(uuid_3);
});

// Test position index functionality
test('Indexed_Collection - optimized removal with position index', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [...sample_items],
	});

	// Remove an item from the middle
	const result = collection.remove(uuid_3); // Remove 'carrot'

	expect(result).toBe(true);
	expect(collection.size).toBe(4);
	expect(collection.all[0].name).toBe('apple');
	expect(collection.all[1].name).toBe('banana');
	expect(collection.all[2].name).toBe('daikon'); // Should have moved up one position
	expect(collection.all[3].name).toBe('eggplant');

	// Re-adding and removing should maintain correct indexes
	const new_item = create_test_item(Uuid.parse(undefined), 'fig', 'fruit', ['purple']);
	collection.add(new_item);
	expect(collection.all[4].name).toBe('fig');

	collection.remove(uuid_1); // Remove 'apple'
	expect(collection.all[0].name).toBe('banana');
	expect(collection.all[3].name).toBe('fig');
});

test('Indexed_Collection - position index works with reordering', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [...sample_items.slice(0, 3)], // apple, banana, carrot
	});

	// Move carrot to the beginning
	collection.reorder(2, 0);

	expect(collection.all[0].name).toBe('carrot');
	expect(collection.all[1].name).toBe('apple');
	expect(collection.all[2].name).toBe('banana');

	// Remove the middle item
	collection.remove(uuid_1); // Remove 'apple'

	// Should maintain correct order
	expect(collection.all[0].name).toBe('carrot');
	expect(collection.all[1].name).toBe('banana');
});

test('Indexed_Collection - position index works with add_first', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [...sample_items.slice(0, 2)], // apple, banana
	});

	// Add carrot to the beginning
	collection.add_first(sample_items[2]); // carrot

	expect(collection.all[0].name).toBe('carrot');
	expect(collection.all[1].name).toBe('apple');
	expect(collection.all[2].name).toBe('banana');

	// Remove the middle item
	collection.remove(uuid_1); // Remove 'apple'

	// Should maintain correct order
	expect(collection.all[0].name).toBe('carrot');
	expect(collection.all[1].name).toBe('banana');
});

// Test handling multiple add/remove operations
test('Indexed_Collection - maintains position indexes after multiple operations', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	// Add three items
	collection.add(sample_items[0]); // apple at index 0
	collection.add(sample_items[1]); // banana at index 1
	collection.add(sample_items[2]); // carrot at index 2

	// Verify initial indexes
	expect(collection.position_index.get(uuid_1)).toBe(0);
	expect(collection.position_index.get(uuid_2)).toBe(1);
	expect(collection.position_index.get(uuid_3)).toBe(2);

	// Remove the middle item
	collection.remove(uuid_2);

	// Verify indexes after removal
	expect(collection.position_index.get(uuid_1)).toBe(0);
	expect(collection.position_index.has(uuid_2)).toBe(false);
	expect(collection.position_index.get(uuid_3)).toBe(1); // moved up

	// Add another item
	collection.add(sample_items[3]); // daikon at index 2

	// Verify indexes after add
	expect(collection.position_index.get(uuid_1)).toBe(0);
	expect(collection.position_index.get(uuid_3)).toBe(1);
	expect(collection.position_index.get(uuid_4)).toBe(2);

	// Add an item at the beginning
	collection.add_first(sample_items[4]); // eggplant at index 0, shifting all others

	// Verify indexes after add_first
	expect(collection.position_index.get(uuid_5)).toBe(0);
	expect(collection.position_index.get(uuid_1)).toBe(1); // shifted
	expect(collection.position_index.get(uuid_3)).toBe(2); // shifted
	expect(collection.position_index.get(uuid_4)).toBe(3); // shifted

	// Reorder (move eggplant to the middle)
	collection.reorder(0, 2);

	// Verify indexes after reorder
	expect(collection.position_index.get(uuid_1)).toBe(0); // moved up
	expect(collection.position_index.get(uuid_3)).toBe(1); // moved up
	expect(collection.position_index.get(uuid_5)).toBe(2); // moved to middle
	expect(collection.position_index.get(uuid_4)).toBe(3); // unchanged

	// Check array order matches position indexes
	for (let i = 0; i < collection.all.length; i++) {
		const id = collection.all[i].id;
		expect(collection.position_index.get(id)).toBe(i);
	}
});

// Add a test specifically for position index lookup consistency
test('Indexed_Collection - position index always matches actual array positions', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: sample_items,
	});

	// Perform a series of operations
	collection.remove(uuid_2); // Remove banana
	collection.add_first(create_test_item(uuid_99, 'fig', 'fruit', []));
	collection.reorder(1, 3); // Move apple to position 3

	// Check that position index matches actual array positions for all items
	for (let i = 0; i < collection.all.length; i++) {
		const id = collection.all[i].id;
		expect(collection.position_index.get(id)).toBe(i);
	}

	// And verify no orphaned entries in position_index
	expect(collection.position_index.size).toBe(collection.all.length);
});

// Test fractional indexing functionality
test('Indexed_Collection - fractional indexing allows efficient insertions', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	// Add initial items
	collection.add(sample_items[0]); // apple
	collection.add(sample_items[1]); // banana

	// Store initial fractional positions
	const frac_apple_initial = collection.fractional_index.get(uuid_1);
	const frac_banana_initial = collection.fractional_index.get(uuid_2);

	// Add item at beginning
	collection.add_first(sample_items[2]); // carrot at start

	// Position indexes SHOULD change because array positions changed
	expect(collection.position_index.get(uuid_1)).toBe(1); // apple moved to index 1
	expect(collection.position_index.get(uuid_2)).toBe(2); // banana moved to index 2
	expect(collection.position_index.get(uuid_3)).toBe(0); // carrot added at index 0

	// But fractional positions of existing items should NOT have changed
	expect(collection.fractional_index.get(uuid_1)).toBe(frac_apple_initial);
	expect(collection.fractional_index.get(uuid_2)).toBe(frac_banana_initial);

	// New item's fractional position should be before first item
	expect(collection.fractional_index.get(uuid_3)).toBeLessThan(frac_apple_initial!);

	// Verify get_ordered_items returns items in the correct order by fractional position
	const ordered_items = collection.get_ordered_items();
	expect(ordered_items[0].name).toBe('carrot');
	expect(ordered_items[1].name).toBe('apple');
	expect(ordered_items[2].name).toBe('banana');
});

test('Indexed_Collection - position rebalancing occurs when needed', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();
	collection.add(sample_items[0]); // apple

	// Add several items to force positions close together
	for (let i = 0; i < 10; i++) {
		// Use a proper UUID format
		const id = `00000000-0000-0000-0000-${i.toString().padStart(12, '0')}` as Uuid;
		const item = create_test_item(id, `item${i}`, 'test', []);
		collection.add_first(item);
	}

	// Manually set fractional positions very close together to force rebalancing
	const items = [...collection.all];
	let current_pos = 10.0;
	const small_gap = 0.01; // Small gap to trigger rebalancing

	// Set decreasing positions with small gaps
	for (let i = 0; i < items.length; i++) {
		collection.fractional_index.set(items[i].id, current_pos);
		current_pos -= small_gap;
	}

	// Trigger rebalance by inserting a new item
	const trigger_item = create_test_item(
		'00000000-0000-0000-0000-000000000099' as Uuid,
		'trigger',
		'test',
		[],
	);
	collection.add_first(trigger_item);

	// After rebalancing, positions should have larger gaps
	const ordered_items = collection.get_ordered_items();
	for (let i = 1; i < ordered_items.length; i++) {
		const prev_pos = collection.fractional_index.get(ordered_items[i - 1].id)!;
		const curr_pos = collection.fractional_index.get(ordered_items[i].id)!;
		const gap = Math.abs(curr_pos - prev_pos);
		expect(gap).toBeGreaterThan(small_gap);
	}
});

test('Indexed_Collection - fractional indexing preserves order with many operations', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: sample_items.slice(0, 3), // apple, banana, carrot
	});

	// Perform a specific series of operations
	collection.add_first(sample_items[3]); // Add daikon at beginning
	// Now: daikon, apple, banana, carrot

	collection.reorder(0, 2); // Move daikon to position 2
	// Now: apple, banana, daikon, carrot

	collection.add(sample_items[4]); // Add eggplant at end
	// Now: apple, banana, daikon, carrot, eggplant

	collection.reorder(4, 1); // Move eggplant from position 4 to position 1
	// Now: apple, eggplant, banana, daikon, carrot

	// Expected order after all operations
	const expected_order = ['apple', 'eggplant', 'banana', 'daikon', 'carrot'];
	const actual_order = collection.all.map((item) => item.name);

	expect(actual_order).toEqual(expected_order);

	// Position indexes should correctly reflect array positions
	for (let i = 0; i < collection.all.length; i++) {
		expect(collection.position_index.get(collection.all[i].id)).toBe(i);
	}

	// Fractional ordering should also produce the same sequence
	const sorted_by_fraction = collection.get_ordered_items().map((item) => item.name);
	expect(sorted_by_fraction).toEqual(expected_order);
});
