// @vitest-environment jsdom

import {test, expect} from 'vitest';
import {Indexed_Collection, type Indexed_Item} from '$lib/indexed_collection.svelte.js';
import {Uuid} from '$lib/zod_helpers.js'; // added import

// Define uuid constants for deterministic testing.
const uuid_1 = Uuid.parse(undefined);
const uuid_2 = Uuid.parse(undefined);
const uuid_3 = Uuid.parse(undefined);
const uuid_4 = Uuid.parse(undefined);
const uuid_5 = Uuid.parse(undefined);
const uuid_99 = Uuid.parse(undefined);

// Helper interfaces and fixtures

interface Test_Item extends Indexed_Item {
	id: Uuid; // updated to use Uuid
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
	expect(collection.array).toEqual([]);
	expect(collection.size).toBe(0);
});

test('Indexed_Collection - initializes with provided items', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1]],
	});

	expect(collection.array.length).toBe(2);
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
	expect(collection.array.length).toBe(2);

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
});

test('Indexed_Collection - add_first method adds items at the beginning', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	collection.add(sample_items[0]);
	collection.add_first(sample_items[1]);

	expect(collection.array[0]).toEqual(sample_items[1]);
	expect(collection.array[1]).toEqual(sample_items[0]);
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

// Removing items
test('Indexed_Collection - remove method removes items by id and updates indexes', () => {
	const collection: Indexed_Collection<Test_Item, 'name' | 'category'> = new Indexed_Collection({
		indexes: [
			{key: 'name', extractor: (item) => item.name},
			{key: 'category', extractor: (item) => item.category, multi: true},
		],
		initial_items: [sample_items[0], sample_items[1], sample_items[2]],
	});

	const removed = collection.remove(uuid_2);

	expect(removed).toBe(true);
	expect(collection.array.length).toBe(2);
	expect(collection.by_id.has(uuid_2)).toBe(false);
	expect(collection.single_indexes.name?.has('banana')).toBe(false);

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
	expect(collection.array.length).toBe(1);
});

// Reordering tests
test('Indexed_Collection - reorder method changes item order', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1], sample_items[2]],
	});

	collection.reorder(0, 2);

	expect(collection.array[0].id).toBe(uuid_2);
	expect(collection.array[1].id).toBe(uuid_3);
	expect(collection.array[2].id).toBe(uuid_1);
});

test('Indexed_Collection - reorder does nothing when indexes are invalid or equal', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1], sample_items[2]],
	});

	// Same index
	collection.reorder(1, 1);
	expect(collection.array[1].id).toBe(uuid_2);

	// Negative index
	collection.reorder(-1, 1);
	expect(collection.array[0].id).toBe(uuid_1);
	expect(collection.array[1].id).toBe(uuid_2);

	// Out of bounds index
	collection.reorder(0, 10);
	expect(collection.array[0].id).toBe(uuid_1);
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

	collection.clear();

	expect(collection.array.length).toBe(0);
	expect(collection.by_id.size).toBe(0);
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

	expect(collection.array.length).toBe(2);
	expect(collection.single_indexes.optional_field?.get('value')).toEqual(item1);
	// The undefined value should not be added to the index
	expect(collection.single_indexes.optional_field?.has(undefined as any)).toBe(false);
});

test('Indexed_Collection - toJSON returns the array snapshot', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1]],
	});

	const json_result = collection.toJSON();
	expect(json_result).toEqual([sample_items[0], sample_items[1]]);
});
