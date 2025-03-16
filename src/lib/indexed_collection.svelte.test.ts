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

// Core functionality: Adding and retrieving items
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

	// Check multi-value index
	expect(collection.multi_indexes.category?.get('fruit')).toEqual([
		sample_items[0],
		sample_items[1],
	]);

	// Check position index
	expect(collection.position_index.get(uuid_1)).toBe(0);
	expect(collection.position_index.get(uuid_2)).toBe(1);
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

// Core functionality: Removing items
test('Indexed_Collection - remove method removes items and updates indexes', () => {
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

// Core functionality: Reordering
test('Indexed_Collection - reorder method changes item order', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1], sample_items[2]],
	});

	collection.reorder(0, 2);

	expect(collection.all[0].id).toBe(uuid_2);
	expect(collection.all[1].id).toBe(uuid_3);
	expect(collection.all[2].id).toBe(uuid_1);

	// Verify position indexes were updated after reordering
	expect(collection.position_index.get(uuid_1)).toBe(2); // moved to end
	expect(collection.position_index.get(uuid_2)).toBe(0); // moved to beginning
	expect(collection.position_index.get(uuid_3)).toBe(1); // moved to middle
});

// Core functionality: Clear
test('Indexed_Collection - clear method resets the collection', () => {
	const collection: Indexed_Collection<Test_Item, 'name' | 'category'> = new Indexed_Collection({
		indexes: [
			{key: 'name', extractor: (item) => item.name},
			{key: 'category', extractor: (item) => item.category, multi: true},
		],
		initial_items: [sample_items[0], sample_items[1], sample_items[2]],
	});

	collection.clear();

	expect(collection.all.length).toBe(0);
	expect(collection.by_id.size).toBe(0);
	expect(collection.position_index.size).toBe(0);
	expect(collection.single_indexes.name?.size).toBe(0);
	expect(collection.multi_indexes.category?.size).toBe(0);
});

// Core functionality: Serialization
test('Indexed_Collection - toJSON returns the array snapshot', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1]],
	});

	const json_result = collection.toJSON();
	expect(json_result).toEqual([sample_items[0], sample_items[1]]);
});

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

// Fractional indexing core functionality
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

	// Fractional ordering should produce the same sequence
	const sorted_by_fraction = collection.get_ordered_items().map((item) => item.name);
	expect(sorted_by_fraction).toEqual(expected_order);
});

// Testing batch operations (add_many, remove_many)
test('Indexed_Collection - add_many adds multiple items efficiently', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	// Add multiple items at once
	const result = collection.add_many(sample_items.slice(0, 3));

	expect(result.length).toBe(3);
	expect(collection.size).toBe(3);
	expect(collection.all[0].name).toBe('apple');
	expect(collection.all[2].name).toBe('carrot');
});

test('Indexed_Collection - remove_many removes multiple items efficiently', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: sample_items,
	});

	// Remove multiple items
	const ids_to_remove = [uuid_1, uuid_3, uuid_5];
	const result = collection.remove_many(ids_to_remove);

	expect(result).toBe(3);
	expect(collection.size).toBe(2);
	expect(collection.all[0].name).toBe('banana');
	expect(collection.all[1].name).toBe('daikon');
});

// Testing position index consistency
test('Indexed_Collection - position index always matches actual array positions', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: sample_items,
	});

	// Perform multiple operations that affect positions
	collection.remove(uuid_2); // Remove banana
	collection.reorder(1, 2); // Move daikon to end
	collection.add_first(create_test_item(Uuid.parse(undefined), 'fig', 'fruit', []));

	// Check consistency between array positions and position index
	for (let i = 0; i < collection.all.length; i++) {
		const id = collection.all[i].id;
		expect(collection.position_index.get(id)).toBe(i);
	}
});

// Testing the optimized index_of method
test('Indexed_Collection - index_of finds positions efficiently', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: sample_items,
	});

	expect(collection.index_of(uuid_3)).toBe(2); // Should use cached position

	// Delete from position index to test lookup
	collection.position_index.delete(uuid_4);
	expect(collection.index_of(uuid_4)).toBe(3); // Should find and cache position
	expect(collection.position_index.get(uuid_4)).toBe(3); // Should be cached now
});
