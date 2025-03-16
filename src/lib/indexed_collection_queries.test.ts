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

// Query method tests
test('Indexed_Collection - where returns all matching items', () => {
	const collection: Indexed_Collection<Test_Item, never, 'category'> = new Indexed_Collection({
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
		initial_items: sample_items,
	});

	const fruits = collection.where('category', 'fruit');
	expect(fruits.length).toBe(2);
	expect(fruits[0].name).toBe('apple');
	expect(fruits[1].name).toBe('banana');

	const vegetables = collection.where('category', 'vegetable');
	expect(vegetables.length).toBe(3);
	expect(vegetables[0].name).toBe('carrot');
	expect(vegetables[2].name).toBe('eggplant');
});

test('Indexed_Collection - where returns empty array for non-existent values', () => {
	const collection: Indexed_Collection<Test_Item, never, 'category'> = new Indexed_Collection({
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
		initial_items: sample_items,
	});

	const nonexistent = collection.where('category', 'dairy');
	expect(nonexistent).toEqual([]);
});

test('Indexed_Collection - first returns the first N items', () => {
	const collection: Indexed_Collection<Test_Item, never, 'category'> = new Indexed_Collection({
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
		initial_items: sample_items,
	});

	const vegetables1 = collection.first('category', 'vegetable', 1);
	expect(vegetables1.length).toBe(1);
	expect(vegetables1[0].name).toBe('carrot');

	const vegetables2 = collection.first('category', 'vegetable', 2);
	expect(vegetables2.length).toBe(2);
	expect(vegetables2[0].name).toBe('carrot');
	expect(vegetables2[1].name).toBe('daikon');
});

test('Indexed_Collection - latest returns the last N items', () => {
	const collection: Indexed_Collection<Test_Item, never, 'category'> = new Indexed_Collection({
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
		initial_items: sample_items,
	});

	const vegetables1 = collection.latest('category', 'vegetable', 1);
	expect(vegetables1.length).toBe(1);
	expect(vegetables1[0].name).toBe('eggplant');

	const vegetables2 = collection.latest('category', 'vegetable', 2);
	expect(vegetables2.length).toBe(2);
	expect(vegetables2[0].name).toBe('daikon');
	expect(vegetables2[1].name).toBe('eggplant');
});

test('Indexed_Collection - related finds items by property reference', () => {
	interface Item_With_Ref extends Indexed_Item {
		id: Uuid;
		name: string;
		ref_id?: Uuid;
	}

	// Create a collection with items and references
	const ref_item1 = {id: uuid_1, name: 'first'};
	const ref_item2 = {id: uuid_2, name: 'second'};
	const item1 = {id: uuid_3, name: 'refers to first', ref_id: uuid_1};
	const item2 = {id: uuid_4, name: 'refers to second', ref_id: uuid_2};
	const item3 = {id: uuid_5, name: 'refers to missing', ref_id: uuid_99};

	const collection: Indexed_Collection<Item_With_Ref> = new Indexed_Collection({
		initial_items: [ref_item1, ref_item2, item1, item2, item3],
	});

	// Find items related to the referring items
	const related_items = collection.related([item1, item2, item3], 'ref_id');

	expect(related_items.length).toBe(2);
	// Use toStrictEqual to compare objects by value rather than reference
	expect(related_items.find((i) => i.id === uuid_1)?.name).toBe('first');
	expect(related_items.find((i) => i.id === uuid_2)?.name).toBe('second');

	// Verify deduplication works by sending duplicate references
	const duplicated_refs = collection.related([item1, item1, item2], 'ref_id');
	expect(duplicated_refs.length).toBe(2); // Still only 2 results
});

test('Indexed_Collection - related handles empty input', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: sample_items,
	});

	const related_items = collection.related([], 'anything');
	expect(related_items).toEqual([]);
});

test('Indexed_Collection - related handles undefined input', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: sample_items,
	});

	const related_items = collection.related(undefined, 'anything');
	expect(related_items).toEqual([]);
});

test('Indexed_Collection - works with both single and multi-indexes', () => {
	const collection: Indexed_Collection<Test_Item, 'name', 'category'> = new Indexed_Collection({
		single_indexes: [
			{key: 'name', extractor: (item) => item.name}, // single-value index
		],
		multi_indexes: [
			{key: 'category', extractor: (item) => item.category}, // multi-value index
		],
		initial_items: sample_items,
	});

	// Test with single-value index (now using by_optional)
	const apple = collection.by_optional('name', 'apple');
	expect(apple).toBeDefined();
	expect(apple?.name).toBe('apple');

	// Test with multi-value index
	const vegetables = collection.where('category', 'vegetable');
	expect(vegetables.length).toBe(3);
});

test('Indexed_Collection - handles edge cases with filtering', () => {
	interface Special_Item extends Indexed_Item {
		id: Uuid;
		name: string;
		value: number | null | undefined;
	}

	const items = [
		{id: uuid_1, name: 'a', value: 1},
		{id: uuid_2, name: 'b', value: null},
		{id: uuid_3, name: 'c', value: undefined},
		{id: uuid_4, name: 'd', value: 0},
	];

	const collection: Indexed_Collection<Special_Item, 'value', never> = new Indexed_Collection({
		single_indexes: [{key: 'value', extractor: (item) => item.value}],
		initial_items: items,
	});

	// Check that null and undefined values are handled properly
	expect(collection.by_optional('value', 1)).toBeDefined();
	expect(collection.by_optional('value', 0)).toBeDefined();
	expect(collection.by_optional('value', null)).toBeUndefined(); // null values aren't indexed
	expect(collection.by_optional('value', undefined)).toBeUndefined(); // undefined values aren't indexed
});

test('Indexed_Collection - integrates well with messages use cases', () => {
	// Simulate a message-like structure
	interface Message extends Indexed_Item {
		id: Uuid;
		type: string;
		ping_id?: Uuid;
		timestamp: number;
	}

	const ping1 = {id: uuid_1, type: 'ping', timestamp: 100};
	const ping2 = {id: uuid_2, type: 'ping', timestamp: 300};
	const pong1 = {id: uuid_3, type: 'pong', ping_id: uuid_1, timestamp: 200};
	const pong2 = {id: uuid_4, type: 'pong', ping_id: uuid_2, timestamp: 400};

	const collection: Indexed_Collection<Message, never, 'type'> = new Indexed_Collection({
		multi_indexes: [{key: 'type', extractor: (item) => item.type}],
		initial_items: [ping1, ping2, pong1, pong2],
	});

	// Get latest pongs
	const latest_pongs = collection.latest('type', 'pong', 1);
	expect(latest_pongs.length).toBe(1);
	expect(latest_pongs[0].id).toBe(uuid_4);

	// Get related pings from pongs
	const pongs = collection.where('type', 'pong');
	const related_pings = collection.related(pongs, 'ping_id');
	expect(related_pings.length).toBe(2);
	expect(related_pings[0].type).toBe('ping');
	expect(related_pings[1].type).toBe('ping');
});

// Test composing multiple where calls for filtering
test('Indexed_Collection - filtering by combining multiple where calls', () => {
	// Add items with multiple attributes to filter by
	const collection: Indexed_Collection<Test_Item, never, 'category' | 'tags'> =
		new Indexed_Collection({
			multi_indexes: [
				{key: 'category', extractor: (item) => item.category},
				{key: 'tags', extractor: (item) => item.tags[0]},
			],
			initial_items: sample_items,
		});

	// Filter by category first
	const fruits = collection.where('category', 'fruit');
	expect(fruits.length).toBe(2);

	// Further filter the fruits by their first tag
	const red_fruits = fruits.filter((item) => item.tags[0] === 'red');
	expect(red_fruits.length).toBe(1);
	expect(red_fruits[0].name).toBe('apple');
});

// Test using latest/first with different limit values
test('Indexed_Collection - latest and first methods respect different limit values', () => {
	const collection: Indexed_Collection<Test_Item, never, 'category'> = new Indexed_Collection({
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
		initial_items: sample_items,
	});

	// Get with different limits
	const one_vegetable = collection.latest('category', 'vegetable', 1);
	const two_vegetables = collection.latest('category', 'vegetable', 2);
	const all_vegetables = collection.latest('category', 'vegetable', 10); // Limit exceeds available items

	expect(one_vegetable.length).toBe(1);
	expect(two_vegetables.length).toBe(2);
	expect(all_vegetables.length).toBe(3); // Should only return the 3 available vegetables

	// Test extreme values - these should return empty arrays now
	const zero_limit = collection.latest('category', 'vegetable', 0);
	expect(zero_limit.length).toBe(0);

	const negative_limit = collection.latest('category', 'vegetable', -1);
	expect(negative_limit.length).toBe(0);
});

// Test the related method with nested property paths
test('Indexed_Collection - related method with nested properties', () => {
	interface Nested_Item extends Indexed_Item {
		id: Uuid;
		name: string;
		refs: {
			primary?: Uuid;
			secondary?: Uuid;
		};
	}

	const ref1 = {id: uuid_1, name: 'reference1', refs: {}};
	const ref2 = {id: uuid_2, name: 'reference2', refs: {}};

	const item1 = {
		id: uuid_3,
		name: 'item_with_primary',
		refs: {
			primary: uuid_1,
		},
	};

	const item2 = {
		id: uuid_4,
		name: 'item_with_secondary',
		refs: {
			secondary: uuid_2,
		},
	};

	const collection: Indexed_Collection<Nested_Item> = new Indexed_Collection({
		initial_items: [ref1, ref2, item1, item2],
	});

	// Access nested properties
	const primary_refs = collection.related([item1], 'refs.primary');
	const secondary_refs = collection.related([item2], 'refs.secondary');

	expect(primary_refs.length).toBe(1);
	expect(primary_refs[0].name).toBe('reference1');

	expect(secondary_refs.length).toBe(1);
	expect(secondary_refs[0].name).toBe('reference2');
});

// Test the chaining of collection operations
test('Indexed_Collection - chaining operations on filtered results', () => {
	// Add more complex data structure
	interface Task_Item extends Indexed_Item {
		id: Uuid;
		title: string;
		status: 'todo' | 'in_progress' | 'done';
		priority: number;
		assigned_to?: Uuid;
	}

	// Create users
	const user1 = {id: uuid_1, title: 'User 1', status: 'todo' as const, priority: 0};
	const user2 = {id: uuid_2, title: 'User 2', status: 'todo' as const, priority: 0};

	// Create tasks with different statuses and priorities
	const tasks = [
		{id: uuid_3, title: 'Task 1', status: 'todo' as const, priority: 1, assigned_to: uuid_1},
		{id: uuid_4, title: 'Task 2', status: 'in_progress' as const, priority: 2, assigned_to: uuid_1},
		{id: uuid_5, title: 'Task 3', status: 'done' as const, priority: 3, assigned_to: uuid_2},
		{
			id: Uuid.parse(undefined),
			title: 'Task 4',
			status: 'todo' as const,
			priority: 4,
			assigned_to: uuid_2,
		},
		{
			id: Uuid.parse(undefined),
			title: 'Task 5',
			status: 'in_progress' as const,
			priority: 5,
			assigned_to: uuid_1,
		},
	];

	const collection: Indexed_Collection<Task_Item, never, 'status' | 'assigned_to'> =
		new Indexed_Collection({
			multi_indexes: [
				{key: 'status', extractor: (item) => item.status},
				{key: 'assigned_to', extractor: (item) => item.assigned_to},
			],
			initial_items: [user1, user2, ...tasks] as Array<Task_Item>,
		});

	// Get all tasks for user1
	const user1_tasks = collection.where('assigned_to', uuid_1);
	expect(user1_tasks.length).toBe(3);

	// Filter to only in-progress tasks
	const user1_in_progress = user1_tasks.filter((task) => task.status === 'in_progress');
	expect(user1_in_progress.length).toBe(2);

	// Sort by priority
	const sorted_by_priority = [...user1_in_progress].sort((a, b) => a.priority - b.priority);
	expect(sorted_by_priority[0].title).toBe('Task 2');
	expect(sorted_by_priority[1].title).toBe('Task 5');

	// Test query chaining
	const high_priority_tasks = collection
		.where('status', 'in_progress')
		.filter((task) => task.priority > 3);

	expect(high_priority_tasks.length).toBe(1);
	expect(high_priority_tasks[0].title).toBe('Task 5');
});

// Test for type safety of the API
test('Indexed_Collection - ensures type safety in query methods', () => {
	const collection: Indexed_Collection<Test_Item, never, 'category'> = new Indexed_Collection({
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
		initial_items: sample_items,
	});

	// Type safe value lookup - we're checking that this compiles correctly
	// TypeScript should enforce that the value matches the type defined in the index
	const fruits = collection.where('category', 'fruit');

	// Check result type
	expect(Array.isArray(fruits)).toBe(true);

	// This would be a TypeScript error if the API is correctly typed:
	// const invalid = collection.where('category', 123); // Type error
});

// Add tests for batch operations with querying
test('Indexed_Collection - batch operations work correctly with querying', () => {
	const collection: Indexed_Collection<Test_Item, never, 'category'> = new Indexed_Collection({
		multi_indexes: [{key: 'category', extractor: (item) => item.category}],
	});

	// Add multiple items at once with add_many
	const fruits = [
		create_test_item(Uuid.parse(undefined), 'apple', 'fruit', ['red']),
		create_test_item(Uuid.parse(undefined), 'banana', 'fruit', ['yellow']),
		create_test_item(Uuid.parse(undefined), 'cherry', 'fruit', ['red']),
	];

	const vegetables = [
		create_test_item(Uuid.parse(undefined), 'carrot', 'vegetable', ['orange']),
		create_test_item(Uuid.parse(undefined), 'daikon', 'vegetable', ['white']),
	];

	collection.add_many(fruits);
	collection.add_many(vegetables);

	// Test querying after batch adds
	const queried_fruits = collection.where('category', 'fruit');
	expect(queried_fruits.length).toBe(3);

	const queried_vegetables = collection.where('category', 'vegetable');
	expect(queried_vegetables.length).toBe(2);

	// Remove multiple items
	const fruit_ids = fruits.slice(0, 2).map((item) => item.id);
	collection.remove_many(fruit_ids);

	// Verify queries work after batch removal
	const remaining_fruits = collection.where('category', 'fruit');
	expect(remaining_fruits.length).toBe(1);
	expect(remaining_fruits[0].name).toBe('cherry');
});

// Test path resolution with complex paths
test('Indexed_Collection - related method with complex nested paths', () => {
	interface Deep_Nested_Item extends Indexed_Item {
		id: Uuid;
		name: string;
		nested: {
			level1: {
				level2: {
					level3: {
						ref_id?: Uuid;
					};
				};
			};
		};
	}

	const target_id = Uuid.parse(undefined);
	const target = {
		id: target_id,
		name: 'target',
		nested: {level1: {level2: {level3: {}}}},
	};

	const reference = {
		id: Uuid.parse(undefined),
		name: 'reference',
		nested: {
			level1: {
				level2: {
					level3: {
						ref_id: target_id,
					},
				},
			},
		},
	};

	const collection: Indexed_Collection<Deep_Nested_Item> = new Indexed_Collection({
		initial_items: [target, reference],
	});

	// Deep path lookup
	const related = collection.related([reference], 'nested.level1.level2.level3.ref_id');

	expect(related.length).toBe(1);
	expect(related[0].id).toStrictEqual(target_id);
});

// Test the performance of large related operations with deduplication
test('Indexed_Collection - related with many duplicate references', () => {
	// Create a collection with some target items
	const targets: Array<Test_Item> = [];
	const refs: Array<{id: Uuid; ref_id: Uuid}> = [];

	// Add 5 target items
	for (let i = 0; i < 5; i++) {
		const id = Uuid.parse(undefined);
		targets.push(create_test_item(id, `target${i}`, 'target', []));
	}

	// Create 200 references pointing to just the 5 targets (many duplicates)
	for (let i = 0; i < 200; i++) {
		const target_idx = i % 5; // Will create many duplicates
		refs.push({
			id: Uuid.parse(undefined),
			ref_id: targets[target_idx].id,
		});
	}

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: targets,
	});

	// This should return just 5 items despite having 200 references
	const related_items = collection.related(refs, 'ref_id');
	expect(related_items.length).toBe(5);
});

// Test combining path resolution with array operations
test('Indexed_Collection - related with array operations and filters', () => {
	interface Complex_Item extends Indexed_Item {
		id: Uuid;
		refs: Array<{id: Uuid; type: string}>;
	}

	const target1: Complex_Item = {id: Uuid.parse(undefined), refs: []};
	const target2: Complex_Item = {id: Uuid.parse(undefined), refs: []};

	const source = {
		id: Uuid.parse(undefined),
		refs: [
			{id: target1.id, type: 'primary'},
			{id: target2.id, type: 'secondary'},
			{id: Uuid.parse(undefined), type: 'missing'}, // This ID doesn't exist
		],
	};

	const collection: Indexed_Collection<Complex_Item> = new Indexed_Collection({
		initial_items: [target1, target2],
	});

	// Get the first array item
	const primary_ref = collection.related([source], 'refs.0.id');
	expect(primary_ref.length).toBe(1);
	expect(primary_ref[0].id).toStrictEqual(target1.id);

	// Get the second array item
	const secondary_ref = collection.related([source], 'refs.1.id');
	expect(secondary_ref.length).toBe(1);
	expect(secondary_ref[0].id).toStrictEqual(target2.id);

	// Missing item should return empty
	const missing_ref = collection.related([source], 'refs.2.id');
	expect(missing_ref.length).toBe(0);
});

// Test for the updated by/by_optional methods with single indexes
test('Indexed_Collection - by and by_optional methods with single indexes', () => {
	const collection: Indexed_Collection<Test_Item, 'name', never> = new Indexed_Collection({
		single_indexes: [{key: 'name', extractor: (item) => item.name}],
		initial_items: sample_items,
	});

	// Using by to get an item that exists
	const apple = collection.by('name', 'apple');
	expect(apple.name).toBe('apple');

	// by should throw on missing item
	expect(() => collection.by('name', 'nonexistent')).toThrow();

	// by_optional should return undefined for missing items
	const missing = collection.by_optional('name', 'nonexistent');
	expect(missing).toBeUndefined();

	// by_optional should return the item for existing items
	const banana = collection.by_optional('name', 'banana');
	expect(banana?.name).toBe('banana');
});
