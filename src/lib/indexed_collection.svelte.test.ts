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
	const collection: Indexed_Collection<Test_Item, 'name', 'category'> = new Indexed_Collection({
		single_indexes: [{key: 'name', extractor: (item) => item.name}],
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
	});

	expect(collection.single_indexes.name).toBeDefined();
	expect(collection.multi_indexes.category).toBeDefined();
});

test('Indexed_Collection - initializes with multiple indexes of different types', () => {
	const collection: Indexed_Collection<Test_Item, 'name', 'category' | 'tags'> =
		new Indexed_Collection({
			single_indexes: [{key: 'name', extractor: (item) => item.name}],
			multi_indexes: [
				{key: 'category', extractor: (item) => item.category},
				{key: 'tags', extractor: (item) => item.tags.join(',')},
			],
		});

	expect(collection.single_indexes.name).toBeDefined();
	expect(collection.multi_indexes.category).toBeDefined();
	expect(collection.multi_indexes.tags).toBeDefined();
});

// Core functionality: Adding and retrieving items
test('Indexed_Collection - add method adds items and updates indexes', () => {
	const collection: Indexed_Collection<Test_Item, 'name', 'category'> = new Indexed_Collection({
		single_indexes: [{key: 'name', extractor: (item) => item.name}],
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
	});

	collection.add(sample_items[0]);
	collection.add(sample_items[1]);

	// Check main array
	expect(collection.all.length).toBe(2);

	// Check primary index
	expect(collection.by_id.get(uuid_1)).toEqual(sample_items[0]);

	// Check single-value index
	expect(collection.single_indexes.name.get('apple')).toEqual(sample_items[0]);

	// Check multi-value index
	expect(collection.multi_indexes.category.get('fruit')).toEqual([
		sample_items[0],
		sample_items[1],
	]);
});

test('Indexed_Collection - add_first method adds items at the beginning', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	collection.add(sample_items[0]);
	collection.add_first(sample_items[1]);

	expect(collection.all[0]).toEqual(sample_items[1]);
	expect(collection.all[1]).toEqual(sample_items[0]);
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
	const collection: Indexed_Collection<Test_Item, 'name', 'category'> = new Indexed_Collection({
		single_indexes: [{key: 'name', extractor: (item) => item.name}],
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
		initial_items: [sample_items[0], sample_items[1], sample_items[2]],
	});

	const removed = collection.remove(uuid_2);

	expect(removed).toBe(true);
	expect(collection.all.length).toBe(2);
	expect(collection.by_id.has(uuid_2)).toBe(false);
	expect(collection.single_indexes.name.has('banana')).toBe(false);

	// Check that the category index was updated properly
	const fruit_items = collection.multi_indexes.category.get('fruit');
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
});

// Core functionality: Clear
test('Indexed_Collection - clear method resets the collection', () => {
	const collection: Indexed_Collection<Test_Item, 'name', 'category'> = new Indexed_Collection({
		single_indexes: [{key: 'name', extractor: (item) => item.name}],
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
		initial_items: [sample_items[0], sample_items[1], sample_items[2]],
	});

	collection.clear();

	expect(collection.all.length).toBe(0);
	expect(collection.by_id.size).toBe(0);
	expect(collection.single_indexes.name.size).toBe(0);
	expect(collection.multi_indexes.category.size).toBe(0);
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

// Testing the optimized index_of method
test('Indexed_Collection - index_of finds positions correctly', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: sample_items,
	});

	expect(collection.index_of(uuid_3)).toBe(2);
	expect(collection.index_of(uuid_4)).toBe(3);
});

// Testing single index by and by_optional methods
test('Indexed_Collection - by method returns items by single-value index', () => {
	const collection: Indexed_Collection<Test_Item, 'name', never> = new Indexed_Collection({
		single_indexes: [{key: 'name', extractor: (item) => item.name}],
		initial_items: [sample_items[0], sample_items[1]],
	});

	expect(() => collection.by('name', 'apple')).not.toThrow();
	expect(collection.by('name', 'apple')).toEqual(sample_items[0]);

	expect(() => collection.by('name', 'nonexistent')).toThrow();
});

test('Indexed_Collection - by_optional method returns items or undefined', () => {
	const collection: Indexed_Collection<Test_Item, 'name', never> = new Indexed_Collection({
		single_indexes: [{key: 'name', extractor: (item) => item.name}],
		initial_items: [sample_items[0], sample_items[1]],
	});

	expect(collection.by_optional('name', 'apple')).toEqual(sample_items[0]);
	expect(collection.by_optional('name', 'nonexistent')).toBeUndefined();
});
