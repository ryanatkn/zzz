// @vitest-environment jsdom

import {test, expect} from 'vitest';
import {Indexed_Collection, type Indexed_Item} from '$lib/indexed_collection.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';

// Define uuid constants for deterministic testing
const uuid_1 = Uuid.parse(undefined);
const uuid_2 = Uuid.parse(undefined);
const uuid_3 = Uuid.parse(undefined);
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

// Test constructor edge cases
test('Indexed_Collection - initializes with empty options object', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({});

	expect(collection.all).toEqual([]);
	expect(collection.size).toBe(0);
	expect(collection.by_id.size).toBe(0);
});

test('Indexed_Collection - initializes with empty index arrays', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		single_indexes: [],
		multi_indexes: [],
	});

	expect(collection.all).toEqual([]);
	expect(collection.single_indexes).toEqual({});
	expect(collection.multi_indexes).toEqual({});
});

// Edge cases when removing items
test('Indexed_Collection - remove method returns false when id not found', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();
	collection.add(create_test_item(uuid_1, 'apple', 'fruit', []));

	const removed = collection.remove(uuid_99);

	expect(removed).toBe(false);
	expect(collection.all.length).toBe(1);
});

test('Indexed_Collection - remove from empty collection', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	const removed = collection.remove(uuid_1);

	expect(removed).toBe(false);
});

// Edge cases with index values
test('Indexed_Collection - handles null/undefined index values', () => {
	interface Item_With_Optional extends Indexed_Item {
		id: Uuid;
		optional_field?: string;
	}

	const collection: Indexed_Collection<Item_With_Optional, 'optional_field', never> =
		new Indexed_Collection<Item_With_Optional, 'optional_field', never>({
			single_indexes: [{key: 'optional_field', extractor: (item) => item.optional_field}],
		});

	const item1 = {id: uuid_1, optional_field: 'value'};
	const item2 = {id: uuid_2}; // optional_field is undefined

	collection.add(item1);
	collection.add(item2);

	expect(collection.all.length).toBe(2);
	expect(collection.single_indexes.optional_field.get('value')).toEqual(item1);
	// The undefined value should not be added to the index
	expect(collection.single_indexes.optional_field.has(undefined as any)).toBe(false);
});

test('Indexed_Collection - null/undefined extractor values are handled consistently', () => {
	interface Nullable_Item extends Indexed_Item {
		id: Uuid;
		nullable_value: string | null | undefined;
	}

	const collection: Indexed_Collection<Nullable_Item, 'nullable', never> = new Indexed_Collection({
		single_indexes: [{key: 'nullable', extractor: (item) => item.nullable_value}],
	});

	const item1 = {id: uuid_1, nullable_value: 'value'};
	const item2 = {id: uuid_2, nullable_value: null};
	const item3 = {id: uuid_3, nullable_value: undefined};

	collection.add(item1);
	collection.add(item2);
	collection.add(item3);

	expect(collection.all.length).toBe(3);
	expect(collection.single_indexes.nullable.get('value')).toEqual(item1);

	// Null and undefined values should not be added to the index
	expect(collection.single_indexes.nullable.has(null as any)).toBe(false);
	expect(collection.single_indexes.nullable.has(undefined as any)).toBe(false);

	// But the items should still be retrievable by ID
	expect(collection.get(uuid_2)).toBe(item2);
	expect(collection.get(uuid_3)).toBe(item3);
});

// Edge cases with reordering
test('Indexed_Collection - reorder does nothing when indexes are invalid or equal', () => {
	const test_items = [
		create_test_item(uuid_1, 'apple', 'fruit', []),
		create_test_item(uuid_2, 'banana', 'fruit', []),
		create_test_item(uuid_3, 'carrot', 'vegetable', []),
	];

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: test_items,
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

test('Indexed_Collection - first/latest methods handle empty results gracefully', () => {
	const collection: Indexed_Collection<Test_Item, never, 'category'> = new Indexed_Collection({
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
	});

	const empty_first = collection.first('category', 'nonexistent', 5);
	const empty_latest = collection.latest('category', 'nonexistent', 5);

	expect(empty_first).toBeInstanceOf(Array);
	expect(empty_first.length).toBe(0);
	expect(empty_latest).toBeInstanceOf(Array);
	expect(empty_latest.length).toBe(0);
});

test('Indexed_Collection - latest and first methods handle edge case limit values', () => {
	const test_items = [
		create_test_item(uuid_1, 'apple', 'fruit', []),
		create_test_item(uuid_2, 'banana', 'fruit', []),
		create_test_item(uuid_3, 'carrot', 'vegetable', []),
	];

	const collection: Indexed_Collection<Test_Item, never, 'category'> = new Indexed_Collection({
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
		initial_items: test_items,
	});

	// Test extreme values - these should return empty arrays
	const zero_limit = collection.latest('category', 'vegetable', 0);
	expect(zero_limit.length).toBe(0);

	const negative_limit = collection.latest('category', 'vegetable', -1);
	expect(negative_limit.length).toBe(0);

	// Greater than available items
	const all_fruits = collection.first('category', 'fruit', 10);
	expect(all_fruits.length).toBe(2); // Only returns available items
});

// Handling circular references
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

	const collection: Indexed_Collection<Recursive_Item, 'name', never> = new Indexed_Collection({
		single_indexes: [{key: 'name', extractor: (item) => item.name}],
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

// Edge case with inconsistent state
test('Indexed_Collection - index_of handles item not in array', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();
	const item = create_test_item(uuid_1, 'apple', 'fruit', []);

	// Add item to by_id but not to the array (simulating inconsistent state)
	collection.by_id.set(uuid_1, item);

	// Should return undefined when item is not in array
	expect(collection.index_of(uuid_1)).toBeUndefined();
});

// Test handling of duplicate keys in multi-indexes
test('Indexed_Collection - handles duplicate values in multi-indexes', () => {
	const collection: Indexed_Collection<Test_Item, never, 'tag'> = new Indexed_Collection({
		multi_indexes: [
			// Use a single tag extractor that returns the first tag
			{key: 'tag', extractor: (item) => item.tags[0]},
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

// Test adding an item at an invalid position
test('Indexed_Collection - insert_at throws for invalid indexes', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();
	const item = create_test_item(uuid_1, 'apple', 'fruit', []);

	// Insert at negative position should throw
	expect(() => {
		collection.insert_at(item, -1);
	}).toThrow();

	// Insert at position larger than array length should throw
	expect(() => {
		collection.insert_at(item, 1); // Array length is 0
	}).toThrow();
});

// Test related with unusual path structures
test('Indexed_Collection - related handles complex and invalid paths', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();
	const item = create_test_item(uuid_1, 'apple', 'fruit', []);
	collection.add(item);

	// Empty source array
	expect(collection.related([], 'id')).toEqual([]);

	// Invalid path that doesn't exist on source object
	const source = {id: uuid_1, something: 'else'};
	expect(collection.related([source], 'nonexistent.path')).toEqual([]);

	// Path resolves to non-ID value
	const source2 = {id: uuid_1, nested: {value: 'not-an-id'}};
	expect(collection.related([source2], 'nested.value')).toEqual([]);

	// Path with array index out of bounds
	const source3 = {id: uuid_1, array: [uuid_1]};
	expect(collection.related([source3], 'array[5]')).toEqual([]);
});

// Test empty collection serialization
test('Indexed_Collection - empty collection serializes to empty array', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	const json = JSON.stringify(collection);
	expect(json).toBe('[]');

	// Deserialize empty collection
	const parsed = JSON.parse(json);
	expect(parsed).toEqual([]);
});

// Test by method edge cases
test('Indexed_Collection - by method throws with appropriate error message', () => {
	const collection: Indexed_Collection<Test_Item, 'name', never> = new Indexed_Collection({
		single_indexes: [{key: 'name', extractor: (item) => item.name}],
		initial_items: [create_test_item(uuid_1, 'apple', 'fruit', [])],
	});

	// Should throw with a message that includes the index key and value
	expect(() => {
		collection.by('name', 'nonexistent');
	}).toThrow(/Item not found for index name with value nonexistent/);
});

// Test index configuration merging
test('Indexed_Collection - handles both single and multi index configurations', () => {
	const collection: Indexed_Collection<Test_Item, 'name', 'category'> = new Indexed_Collection({
		single_indexes: [{key: 'name', extractor: (item) => item.name}],
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
	});

	const item = create_test_item(uuid_1, 'apple', 'fruit', []);
	collection.add(item);

	// Should be able to query by both single and multi index
	expect(collection.by('name', 'apple')).toBe(item);
	expect(collection.where('category', 'fruit')).toContainEqual(item);
});
