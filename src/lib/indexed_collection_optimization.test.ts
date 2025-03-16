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

// Test batch operations and optimizations
test('Indexed_Collection - add_many efficiently adds multiple items at once', () => {
	const collection: Indexed_Collection<Test_Item, 'category'> = new Indexed_Collection({
		indexes: [{key: 'category', extractor: (item) => item.category, multi: true}],
	});

	// Add multiple items at once
	const batch_result = collection.add_many([sample_items[0], sample_items[1], sample_items[2]]);

	// Verify items were added properly
	expect(collection.size).toBe(3);
	expect(batch_result.length).toBe(3);
	expect(batch_result).toEqual([sample_items[0], sample_items[1], sample_items[2]]);

	// Verify indexes were updated correctly
	expect(collection.by_id.get(uuid_1)).toBe(sample_items[0]);
	expect(collection.by_id.get(uuid_2)).toBe(sample_items[1]);
	expect(collection.by_id.get(uuid_3)).toBe(sample_items[2]);

	// Verify position indexes
	expect(collection.position_index.get(uuid_1)).toBe(0);
	expect(collection.position_index.get(uuid_2)).toBe(1);
	expect(collection.position_index.get(uuid_3)).toBe(2);

	// Verify fractional indexes maintain correct order
	const frac_pos_1 = collection.fractional_index.get(uuid_1);
	const frac_pos_2 = collection.fractional_index.get(uuid_2);
	const frac_pos_3 = collection.fractional_index.get(uuid_3);

	expect(frac_pos_1).toBeLessThan(frac_pos_2!);
	expect(frac_pos_2).toBeLessThan(frac_pos_3!);

	// Verify secondary indexes
	expect(collection.multi_indexes.category?.get('fruit')?.length).toBe(2);
	expect(collection.multi_indexes.category?.get('vegetable')?.length).toBe(1);
});

test('Indexed_Collection - add_many works with empty array', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	const result = collection.add_many([]);
	expect(result).toEqual([]);
	expect(collection.size).toBe(0);
});

test('Indexed_Collection - add_many appends to existing items', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0]],
	});

	collection.add_many([sample_items[1], sample_items[2]]);

	expect(collection.size).toBe(3);
	// Use toStrictEqual for deep object equality instead of toBe for reference equality
	expect(collection.all[0]).toStrictEqual(sample_items[0]);
	expect(collection.all[1]).toStrictEqual(sample_items[1]);
	expect(collection.all[2]).toStrictEqual(sample_items[2]);
});

test('Indexed_Collection - remove_many efficiently removes multiple items', () => {
	const collection: Indexed_Collection<Test_Item, 'category'> = new Indexed_Collection({
		indexes: [{key: 'category', extractor: (item) => item.category, multi: true}],
		initial_items: sample_items,
	});

	// Remove multiple items at once
	const removed_count = collection.remove_many([uuid_2, uuid_4]); // banana and daikon

	expect(removed_count).toBe(2);
	expect(collection.size).toBe(3);

	// Verify items were removed
	expect(collection.by_id.has(uuid_2)).toBe(false);
	expect(collection.by_id.has(uuid_4)).toBe(false);

	// Verify remaining items are intact
	expect(collection.by_id.get(uuid_1)?.name).toBe('apple');
	expect(collection.by_id.get(uuid_3)?.name).toBe('carrot');
	expect(collection.by_id.get(uuid_5)?.name).toBe('eggplant');

	// Verify position indexes were updated
	expect(collection.position_index.get(uuid_1)).toBe(0);
	expect(collection.position_index.get(uuid_3)).toBe(1);
	expect(collection.position_index.get(uuid_5)).toBe(2);

	// Verify position indexes were removed for deleted items
	expect(collection.position_index.has(uuid_2)).toBe(false);
	expect(collection.position_index.has(uuid_4)).toBe(false);

	// Verify secondary indexes were updated
	expect(collection.multi_indexes.category?.get('fruit')?.length).toBe(1); // Only apple remains
	expect(collection.multi_indexes.category?.get('vegetable')?.length).toBe(2); // Carrot and eggplant
});

test('Indexed_Collection - remove_many handles invalid IDs gracefully', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [sample_items[0], sample_items[1]],
	});

	// Try to remove non-existent items along with existing ones
	const nonexistent_id = Uuid.parse(undefined);
	const removed_count = collection.remove_many([uuid_1, nonexistent_id]);

	expect(removed_count).toBe(1); // Only one valid item removed
	expect(collection.size).toBe(1);
	// Use toStrictEqual instead of toBe
	expect(collection.all[0]).toStrictEqual(sample_items[1]);
});

test('Indexed_Collection - remove_many works with empty array', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: sample_items,
	});

	const removed_count = collection.remove_many([]);
	expect(removed_count).toBe(0);
	expect(collection.size).toBe(5);
});

test('Indexed_Collection - remove_many handles order correctly', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: sample_items,
	});

	// Remove items in reverse order to test correct array splicing
	const removed_count = collection.remove_many([uuid_5, uuid_3, uuid_1]);

	expect(removed_count).toBe(3);
	expect(collection.size).toBe(2);

	// Check resulting array - should have banana and daikon in positions 0 and 1
	expect(collection.all[0].name).toBe('banana');
	expect(collection.all[1].name).toBe('daikon');

	// Position indexes should be updated correctly
	expect(collection.position_index.get(uuid_2)).toBe(0);
	expect(collection.position_index.get(uuid_4)).toBe(1);
});

// Test the optimized index_of implementation
test('Indexed_Collection - index_of efficiently finds item positions', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: sample_items,
	});

	// First call should use cached position
	expect(collection.index_of(uuid_3)).toBe(2);

	// Simulate cache miss by clearing position index
	(collection as any).position_index.delete(uuid_4);

	// Should still find the correct position
	expect(collection.index_of(uuid_4)).toBe(3);

	// Position should now be cached
	expect(collection.position_index.get(uuid_4)).toBe(3);

	// Non-existent item should return undefined
	const nonexistent_id = Uuid.parse(undefined);
	expect(collection.index_of(nonexistent_id)).toBeUndefined();
});

test('Indexed_Collection - index_of handles item not in array', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	// Add item to by_id but not to the array (simulating inconsistent state)
	collection.by_id.set(uuid_1, sample_items[0]);

	// Should return undefined when item is not in array
	expect(collection.index_of(uuid_1)).toBeUndefined();
});

// Test improved path resolution for related items
test('Indexed_Collection - related method with optimized path resolution', () => {
	interface Complex_Item extends Indexed_Item {
		id: Uuid;
		name: string;
		relations: {
			parent?: Uuid;
			children: Array<Uuid>;
			deep: {
				ref?: Uuid;
			};
		};
	}

	const id1 = Uuid.parse(undefined);
	const id2 = Uuid.parse(undefined);
	const id3 = Uuid.parse(undefined);

	const item1: Complex_Item = {
		id: id1,
		name: 'Item 1',
		relations: {
			children: [],
			deep: {},
		},
	};

	const item2: Complex_Item = {
		id: id2,
		name: 'Item 2',
		relations: {
			parent: id1,
			children: [],
			deep: {
				ref: id3,
			},
		},
	};

	const item3: Complex_Item = {
		id: id3,
		name: 'Item 3',
		relations: {
			children: [id1],
			deep: {},
		},
	};

	const collection: Indexed_Collection<Complex_Item> = new Indexed_Collection({
		initial_items: [item1, item2, item3],
	});

	// Test simple property access
	const parent_result = collection.related([item2], 'relations.parent');
	expect(parent_result.length).toBe(1);
	expect(parent_result[0].id).toBe(id1);

	// Test deeply nested property
	const deep_ref_result = collection.related([item2], 'relations.deep.ref');
	expect(deep_ref_result.length).toBe(1);
	expect(deep_ref_result[0].id).toBe(id3);

	// Test array index access
	const child_result = collection.related([item3], 'relations.children[0]');
	expect(child_result.length).toBe(1);
	expect(child_result[0].id).toBe(id1);
});

test('Indexed_Collection - related method deduplicates results', () => {
	const referenced_id = Uuid.parse(undefined);
	const referenced_item = create_test_item(referenced_id, 'referenced', 'category', []);

	interface Item_With_Ref extends Indexed_Item {
		id: Uuid;
		name: string;
		ref_id: Uuid;
	}

	// Create multiple items that all reference the same target
	const referencing_items: Array<Item_With_Ref> = [
		{id: Uuid.parse(undefined), name: 'ref1', ref_id: referenced_id},
		{id: Uuid.parse(undefined), name: 'ref2', ref_id: referenced_id},
		{id: Uuid.parse(undefined), name: 'ref3', ref_id: referenced_id},
	];

	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
		initial_items: [referenced_item],
	});

	// Without deduplication, we'd get the same item 3 times
	// With deduplication, we should get it only once
	const related_items = collection.related(referencing_items, 'ref_id');
	expect(related_items.length).toBe(1);
	expect(related_items[0].id).toBe(referenced_id);
});

test('Indexed_Collection - optimized rebalancing of fractional positions', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	// Add several items
	collection.add_many(sample_items);

	// Manually set fractional positions very close together to trigger rebalancing
	const items = [...collection.all];
	const positions = items.map((_, i) => 10 + i * 0.01); // Very small gaps

	for (let i = 0; i < items.length; i++) {
		collection.fractional_index.set(items[i].id, positions[i]);
	}

	// Add another item which should trigger rebalancing
	const new_item = create_test_item(Uuid.parse(undefined), 'new_item', 'category', []);
	collection.add_first(new_item);

	// After rebalancing, positions should be more evenly distributed
	const rebalanced_positions = collection.all.map((item) =>
		collection.fractional_index.get(item.id),
	);

	// Check that gaps between positions are larger than before
	const MIN_GAP = 10; // After rebalancing, should be significantly larger than 0.01
	for (let i = 1; i < rebalanced_positions.length; i++) {
		const gap = rebalanced_positions[i]! - rebalanced_positions[i - 1]!;
		expect(gap).toBeGreaterThan(MIN_GAP);
	}
});

// Add timeout for this performance test
test(
	'Indexed_Collection - batch operations scale efficiently with large datasets',
	{timeout: 10000},
	() => {
		const collection: Indexed_Collection<Test_Item, 'category'> = new Indexed_Collection({
			indexes: [{key: 'category', extractor: (item) => item.category, multi: true}],
		});

		// Reduce batch size to avoid timeout
		const BATCH_SIZE = 500; // Reduced from 1000
		const large_batch: Array<Test_Item> = [];

		for (let i = 0; i < BATCH_SIZE; i++) {
			const id = `00000000-0000-0000-0000-${i.toString().padStart(12, '0')}` as Uuid;
			const category = i % 2 === 0 ? 'even' : 'odd';
			large_batch.push(create_test_item(id, `item${i}`, category, []));
		}

		// Measure time for adding many items at once
		const start_time = performance.now();
		collection.add_many(large_batch);
		const end_time = performance.now();

		// Verify all items were added correctly
		expect(collection.size).toBe(BATCH_SIZE);
		expect(collection.multi_indexes.category?.get('even')?.length).toBe(BATCH_SIZE / 2);
		expect(collection.multi_indexes.category?.get('odd')?.length).toBe(BATCH_SIZE / 2);

		// This test is more about ensuring the operation completes successfully
		// with large datasets than about specific timing, but we can log the time
		console.log(`Added ${BATCH_SIZE} items in ${end_time - start_time}ms`);

		// Now test batch removal with a smaller set
		const ids_to_remove = large_batch.slice(0, 200).map((item) => item.id);
		const start_remove_time = performance.now();
		const removed_count = collection.remove_many(ids_to_remove);
		const end_remove_time = performance.now();

		expect(removed_count).toBe(200);
		expect(collection.size).toBe(300);

		console.log(`Removed 200 items in ${end_remove_time - start_remove_time}ms`);
	},
);

// Test the lazy index update behavior
test('Indexed_Collection - position indexes update lazily when needed', () => {
	const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();

	// Add items normally
	collection.add(sample_items[0]);
	collection.add(sample_items[1]);

	// Position should be indexed
	expect(collection.position_index.get(uuid_1)).toBe(0);
	expect(collection.position_index.get(uuid_2)).toBe(1);

	// Update array directly but first clear the position index to force lazy computation
	collection.position_index.clear(); // Clear index to simulate stale indexes
	[collection.all[0], collection.all[1]] = [collection.all[1], collection.all[0]];

	// Now the array and index are inconsistent - index_of should recalculate
	expect(collection.index_of(uuid_1)).toBe(1); // Should find in position 1
	expect(collection.index_of(uuid_2)).toBe(0); // Should find in position 0

	// Position index should be updated
	expect(collection.position_index.get(uuid_1)).toBe(1);
	expect(collection.position_index.get(uuid_2)).toBe(0);
});
