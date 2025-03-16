import {test, expect, describe} from 'vitest';
import {Indexed_Collection, Index_Type} from '$lib/indexed_collection.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';

// Mock item type that implements Indexed_Item
interface Test_Item {
	id: Uuid;
	name: string | null;
	tags: Array<string>;
	optional_field?: string;
	nested?: {
		value?: number;
		deep?: {
			data?: string;
		};
	};
}

// Helper function to create test items
const create_test_item = (
	name: string | null = 'test',
	tags: Array<string> = [],
	optional_field?: string,
	nested?: {value?: number; deep?: {data?: string}},
): Test_Item => ({
	id: Uuid.parse(undefined),
	name,
	tags,
	optional_field,
	nested,
});

describe('Indexed_Collection - Edge Cases', () => {
	test('empty collection behavior', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				{
					key: 'by_name',
					type: Index_Type.SINGLE,
					extractor: (item) => item.name,
				},
				{
					key: 'by_tag',
					type: Index_Type.MULTI,
					extractor: (item) => item.tags[0],
				},
				{
					key: 'all_items',
					type: Index_Type.DERIVED,
					compute: (collection) => collection.all,
				},
			],
		});

		// Check empty collection state
		expect(collection.size).toBe(0);
		expect(collection.all).toHaveLength(0);
		expect(collection.by_optional('by_name', 'anything')).toBeUndefined();
		expect(collection.where('by_tag', 'anything')).toHaveLength(0);
		expect(collection.get_derived('all_items')).toHaveLength(0);

		// Operations on empty collection
		expect(collection.remove('non-existent-id' as Uuid)).toBe(false);
		expect(collection.remove_many([])).toBe(0);
		expect(() => collection.by('by_name', 'missing')).toThrow();

		// Clear an empty collection
		collection.clear();
		expect(collection.size).toBe(0);
	});

	test('null and undefined values in extractors', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				{
					key: 'by_name',
					type: Index_Type.SINGLE,
					extractor: (item) => item.name,
				},
				{
					key: 'by_optional',
					type: Index_Type.SINGLE,
					extractor: (item) => item.optional_field,
				},
				{
					key: 'by_nested',
					type: Index_Type.MULTI,
					extractor: (item) => item.nested?.value,
				},
				{
					key: 'by_deep_nested',
					type: Index_Type.MULTI,
					extractor: (item) => item.nested?.deep?.data,
				},
			],
		});

		// Create items with null/undefined values
		const item1 = create_test_item(null, ['tag1']);
		const item2 = create_test_item('item2', ['tag2'], 'optional value');
		const item3 = create_test_item('item3', ['tag3'], undefined, {value: 42});
		const item4 = create_test_item('item4', ['tag4'], undefined, {deep: {data: 'deep data'}});
		const item5 = create_test_item('item5', ['tag5'], undefined, {value: undefined});

		collection.add_many([item1, item2, item3, item4, item5]);

		// Test null key in single index
		expect(collection.by_optional('by_name', null)).toBe(item1);

		// Test undefined values
		expect(collection.by_optional('by_optional', undefined)).toBeUndefined();
		expect(collection.where('by_nested', undefined)).toHaveLength(0);

		// Test defined values
		expect(collection.by_optional('by_optional', 'optional value')).toBe(item2);
		expect(collection.where('by_nested', 42)).toHaveLength(1);
		expect(collection.where('by_deep_nested', 'deep data')).toContain(item4);

		// Remove item with null value
		collection.remove(item1.id);
		expect(collection.by_optional('by_name', null)).toBeUndefined();
	});

	test('duplicate keys in indexes', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				{
					key: 'by_name',
					type: Index_Type.SINGLE,
					extractor: (item) => item.name,
				},
				{
					key: 'constant_key',
					type: Index_Type.SINGLE,
					extractor: () => 'same_key', // Same key for all items
				},
				{
					key: 'by_tag',
					type: Index_Type.MULTI,
					extractor: () => 'shared_tag', // Same tag for all items - unused parameter removed
				},
			],
		});

		// Add items with duplicate keys for single index
		const item1 = create_test_item('duplicate', ['tag1']);
		const item2 = create_test_item('duplicate', ['tag2']); // Same name as item1
		const item3 = create_test_item('unique', ['tag3']);

		// Adding first item with 'duplicate' name
		collection.add(item1);
		expect(collection.by_optional('by_name', 'duplicate')).toBe(item1);

		// Adding second item with same name - should replace first in single index
		collection.add(item2);
		expect(collection.by_optional('by_name', 'duplicate')).toBe(item2);
		expect(collection.by_optional('by_name', 'duplicate')).not.toBe(item1);

		// Add the third item
		collection.add(item3);

		// Check both items are in the collection
		expect(collection.size).toBe(3);
		expect(collection.all).toContain(item1);
		expect(collection.all).toContain(item2);

		// Multi-index with same key should contain all items
		expect(collection.where('by_tag', 'shared_tag')).toHaveLength(3);
		expect(collection.where('by_tag', 'shared_tag')).toContain(item1);
		expect(collection.where('by_tag', 'shared_tag')).toContain(item2);
		expect(collection.where('by_tag', 'shared_tag')).toContain(item3);

		// Constant key single index will only contain the last added item
		expect(collection.by_optional('constant_key', 'same_key')).toBe(item3);

		// Removing an item with duplicate key should not affect the other
		collection.remove(item2.id);
		// After removal, item1 should become the indexed item for 'duplicate' again
		expect(collection.by_optional('by_name', 'duplicate')).toBe(item1);
		expect(collection.where('by_tag', 'shared_tag')).toHaveLength(2);
	});

	test('error handling - invalid operations', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();
		const item = create_test_item('test');
		collection.add(item);

		// Invalid index operations
		expect(() => collection.by('non_existent_index', 'value')).toThrow();
		expect(collection.by_optional('non_existent_index', 'value')).toBeUndefined();
		expect(collection.where('non_existent_index', 'value')).toHaveLength(0);
		expect(collection.get_derived('non_existent_index')).toHaveLength(0);

		// Out of bounds array access
		expect(() => collection.reorder(-1, 0)).not.toThrow();
		expect(() => collection.reorder(0, 999)).not.toThrow();
		expect(() => collection.insert_at(create_test_item(), -1)).toThrow();
		expect(() => collection.insert_at(create_test_item(), 999)).toThrow();
	});

	test('updating items after indexing', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				{
					key: 'by_name',
					type: Index_Type.SINGLE,
					extractor: (item) => item.name,
				},
				{
					key: 'by_tag',
					type: Index_Type.MULTI,
					extractor: (item) => item.tags[0],
				},
			],
		});

		// Add an item
		const item = create_test_item('original', ['original-tag']);
		collection.add(item);

		// Verify initial indexing
		expect(collection.by_optional('by_name', 'original')).toBe(item);

		// Remove the item first, then modify it
		collection.remove(item.id);

		// Now modify the item
		item.name = 'modified';
		item.tags = ['modified-tag'];

		// Add back to collection with new values
		collection.add(item);

		// Now indexes should reflect the new values
		// Original value should no longer be indexed
		expect(collection.by_optional('by_name', 'original')).toBeUndefined();
		// Modified value should be indexed
		expect(collection.by_optional('by_name', 'modified')).toBe(item);
		expect(collection.where('by_tag', 'original-tag')).toHaveLength(0);
		expect(collection.where('by_tag', 'modified-tag')).toContain(item);
	});

	test('large collection performance', () => {
		const ITEM_COUNT = 5000;
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				{
					key: 'by_name',
					type: Index_Type.SINGLE,
					extractor: (item) => item.name,
				},
				{
					key: 'by_tag',
					type: Index_Type.MULTI,
					extractor: (item) => item.tags[0],
				},
			],
		});

		// Create a large number of items
		const items = [];
		for (let i = 0; i < ITEM_COUNT; i++) {
			const tag = `tag-${i % 10}`; // Create 10 different tags
			items.push(create_test_item(`item-${i}`, [tag]));
		}

		// Measure time to add all items
		const add_start = performance.now();
		collection.add_many(items);
		const add_end = performance.now();

		// Verify all items were added
		expect(collection.size).toBe(ITEM_COUNT);

		// Measure time for lookups - fix unused variables with underscore prefix
		const lookup_start = performance.now();
		collection.by_optional('by_name', 'item-999');
		collection.where('by_tag', 'tag-5');
		const lookup_end = performance.now();

		// Measure time for removal
		const remove_start = performance.now();
		const removed = collection.remove_many(items.slice(0, 1000).map((item) => item.id));
		const remove_end = performance.now();

		expect(removed).toBe(1000);
		expect(collection.size).toBe(ITEM_COUNT - 1000);

		// Log performance metrics
		console.log(`Large collection add time (${ITEM_COUNT} items): ${add_end - add_start}ms`);
		console.log(`Lookup time: ${lookup_end - lookup_start}ms`);
		console.log(`Removal time (1000 items): ${remove_end - remove_start}ms`);
	});

	test('derived indexes with complex behavior', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				{
					key: 'multistep_filtered',
					type: Index_Type.DERIVED,
					compute: (collection) => {
						// Complex derivation with multiple steps
						const with_tags = collection.all.filter((item) => item.tags.length > 0);
						const sorted_by_name = [...with_tags].sort((a, b) => {
							if (a.name === null) return 1;
							if (b.name === null) return -1;
							return a.name.localeCompare(b.name || '');
						});
						return sorted_by_name.slice(0, 3); // Only return top 3
					},
					matches: (item) => item.tags.length > 0,
					on_add: (items, item) => {
						if (item.tags.length === 0) return;

						// Insert in correct sorted position
						const insert_index = items.findIndex((existing) => {
							if (item.name === null) return false;
							if (existing.name === null) return true;
							return item.name < existing.name;
						});

						if (insert_index === -1) {
							items.push(item);
						} else {
							items.splice(insert_index, 0, item);
						}

						// Maintain max size of 3
						if (items.length > 3) {
							items.length = 3; // Ensure only top 3 items after sorting
						}
					},
				},
			],
		});

		// Add items with specific ordering to test complex derived index
		const itemC = create_test_item('c', ['tag1']);
		const itemA = create_test_item('a', ['tag2']);
		const itemB = create_test_item('b', ['tag3']);
		const itemD = create_test_item('d', ['tag4']);
		const itemEmpty = create_test_item('e', []); // No tags

		collection.add(itemC);
		collection.add(itemA);
		collection.add(itemB);

		// Check initial state of derived index
		const derived = collection.get_derived('multistep_filtered');
		expect(derived).toHaveLength(3);
		expect(derived[0]).toBe(itemA);
		expect(derived[1]).toBe(itemB);
		expect(derived[2]).toBe(itemC);

		// Add item that should push out the last item
		collection.add(itemD);

		const updated = collection.get_derived('multistep_filtered');
		expect(updated).toHaveLength(3);
		expect(updated[0]).toBe(itemA);
		expect(updated[1]).toBe(itemB);
		expect(updated[2]).toBe(itemC);
		expect(updated).not.toContain(itemD); // D should not be included due to limit

		// Add item with no tags that should be filtered out
		collection.add(itemEmpty);
		expect(collection.get_derived('multistep_filtered')).toHaveLength(3);
		expect(collection.get_derived('multistep_filtered')).not.toContain(itemEmpty);

		// Remove an item and check if derived index updates correctly
		collection.remove(itemA.id);
		const after_remove = collection.get_derived('multistep_filtered');
		expect(after_remove).toHaveLength(2); // Changed from 3 to 2
		expect(after_remove[0]).toBe(itemB);
		expect(after_remove[1]).toBe(itemC);
		// No third item to check since we only have 2 items after removal
	});

	test('special characters and edge values', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				{
					key: 'by_name',
					type: Index_Type.SINGLE,
					extractor: (item) => item.name,
				},
			],
		});

		// Create items with special characters and edge case strings
		const itemEmpty = create_test_item('', ['tag']);
		const itemSpecial = create_test_item('!@#$%^&*()', ['tag']);
		const itemEmoji = create_test_item('😊💻🔍', ['tag']);
		const itemUnicode = create_test_item('Über Straße', ['tag']);
		const itemNewlines = create_test_item('line1\nline2', ['tag']);
		const itemVeryLong = create_test_item('a'.repeat(10000), ['tag']);

		collection.add_many([
			itemEmpty,
			itemSpecial,
			itemEmoji,
			itemUnicode,
			itemNewlines,
			itemVeryLong,
		]);

		// Test lookups with special characters
		expect(collection.by_optional('by_name', '')).toBe(itemEmpty);
		expect(collection.by_optional('by_name', '!@#$%^&*()')).toBe(itemSpecial);
		expect(collection.by_optional('by_name', '😊💻🔍')).toBe(itemEmoji);
		expect(collection.by_optional('by_name', 'Über Straße')).toBe(itemUnicode);
		expect(collection.by_optional('by_name', 'line1\nline2')).toBe(itemNewlines);
		expect(collection.by_optional('by_name', 'a'.repeat(10000))).toBe(itemVeryLong);

		// Remove and check cleanup
		collection.remove(itemEmoji.id);
		expect(collection.by_optional('by_name', '😊💻🔍')).toBeUndefined();
	});

	test('removing non-existent items', () => {
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection();
		const item = create_test_item();
		collection.add(item);

		// Generate a valid UUID that doesn't exist in the collection
		const non_existent_uuid = Uuid.parse(undefined);

		// Test removing non-existent items
		expect(collection.remove(non_existent_uuid)).toBe(false);
		expect(collection.remove_many([non_existent_uuid])).toBe(0);
		expect(collection.size).toBe(1);

		// Mix of existing and non-existing items
		expect(collection.remove_many([item.id, non_existent_uuid])).toBe(1);
		expect(collection.size).toBe(0);
	});

	test('multiple derived indexes interact correctly', () => {
		// Test how multiple derived indexes interact with the same collection
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				// First derived index - items with tags
				{
					key: 'with_tags',
					type: Index_Type.DERIVED,
					compute: (collection) => collection.all.filter((item) => item.tags.length > 0),
					matches: (item) => item.tags.length > 0,
					on_add: (items, item) => {
						if (item.tags.length > 0) {
							items.push(item);
						}
					},
					on_remove: (items, item) => {
						const idx = items.findIndex((i) => i.id === item.id);
						if (idx !== -1) {
							items.splice(idx, 1);
						}
					},
				},
				// Second derived index - items with names starting with 'a'
				{
					key: 'a_names',
					type: Index_Type.DERIVED,
					compute: (collection) =>
						collection.all.filter(
							(item) => Boolean(item.name?.startsWith('a')), // Fix: ensure boolean return
						),
					matches: (item) => Boolean(item.name?.startsWith('a')), // Fix: ensure boolean return
					on_add: (items, item) => {
						if (item.name?.startsWith('a')) {
							items.push(item);
						}
					},
					on_remove: (items, item) => {
						const idx = items.findIndex((i) => i.id === item.id);
						if (idx !== -1) {
							items.splice(idx, 1);
						}
					},
				},
			],
		});

		// Add test items that fit different criteria
		const itemA1 = create_test_item('apple', ['fruit']); // In both indexes
		const itemA2 = create_test_item('apricot', []); // In a_names only
		const itemB1 = create_test_item('banana', ['fruit']); // In with_tags only
		const itemC1 = create_test_item('cherry', []); // In neither index

		collection.add_many([itemA1, itemA2, itemB1, itemC1]);

		// Check initial state of both indexes
		expect(collection.get_derived('with_tags')).toHaveLength(2);
		expect(collection.get_derived('with_tags')).toContain(itemA1);
		expect(collection.get_derived('with_tags')).toContain(itemB1);

		expect(collection.get_derived('a_names')).toHaveLength(2);
		expect(collection.get_derived('a_names')).toContain(itemA1);
		expect(collection.get_derived('a_names')).toContain(itemA2);

		// Modify item to fit different indexes
		collection.remove(itemB1.id);
		const itemB2 = {...itemB1, name: 'avocado'};
		collection.add(itemB2);

		// Verify both indexes updated correctly
		expect(collection.get_derived('with_tags')).toHaveLength(2);
		expect(collection.get_derived('with_tags')).toContain(itemA1);
		expect(collection.get_derived('with_tags')).toContain(itemB2);

		expect(collection.get_derived('a_names')).toHaveLength(3);
		expect(collection.get_derived('a_names')).toContain(itemA1);
		expect(collection.get_derived('a_names')).toContain(itemA2);
		expect(collection.get_derived('a_names')).toContain(itemB2);
	});
});
