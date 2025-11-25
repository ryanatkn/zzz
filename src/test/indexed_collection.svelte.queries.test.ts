// @slop Claude Sonnet 3.7

// @vitest-environment jsdom

import {test, expect, describe, beforeEach} from 'vitest';
import {z} from 'zod';

import {IndexedCollection} from '$lib/indexed_collection.svelte.js';
import {
	create_single_index,
	create_multi_index,
	create_derived_index,
	type IndexedItem,
} from '$lib/indexed_collection_helpers.svelte.js';
import {create_uuid, Uuid} from '$lib/zod_helpers.js';

// Test item representing a generic item
interface TestItem {
	id: Uuid;
	string_a: string;
	string_b: string;
	array_a: Array<string>;
	string_c: string;
	date_a: Date;
	number_a: number;
	boolean_a: boolean;
}

// Helper to create items with default values that can be overridden
const create_test_item = (overrides: Partial<TestItem> = {}): TestItem => ({
	id: create_uuid(),
	string_a: 'a1',
	string_b: 'b1',
	array_a: ['tag1'],
	string_c: 'c1',
	date_a: new Date(),
	number_a: 3,
	boolean_a: false,
	...overrides,
});

// Helper functions for id-based object equality checks
const has_item_with_id = (array: Array<IndexedItem>, item: IndexedItem): boolean =>
	array.some((i) => i.id === item.id);

describe('IndexedCollection - Query Capabilities', () => {
	let collection: IndexedCollection<TestItem>;
	let items: Array<TestItem>;

	beforeEach(() => {
		// Create a collection with various indexes
		collection = new IndexedCollection<TestItem>({
			indexes: [
				// Single value indexes
				create_single_index({
					key: 'by_string_a',
					extractor: (item) => item.string_a.toLowerCase(), // Case insensitive
					query_schema: z.string(),
				}),
				create_single_index({
					key: 'by_string_b',
					extractor: (item) => item.string_b, // Case sensitive
					query_schema: z.string(),
				}),

				// Multi value indexes
				create_multi_index({
					key: 'by_string_c',
					extractor: (item) => item.string_c,
					query_schema: z.string(),
				}),
				create_multi_index({
					key: 'by_array_a',
					extractor: (item) => item.array_a,
					query_schema: z.string(),
				}),
				create_multi_index({
					key: 'by_number_a',
					extractor: (item) => item.number_a,
					query_schema: z.number(),
				}),
				create_multi_index({
					key: 'by_boolean_a',
					extractor: (item) => (item.boolean_a ? 'y' : 'n'),
					query_schema: z.enum(['y', 'n']),
				}),
				create_multi_index({
					key: 'by_year',
					extractor: (item) => item.date_a.getFullYear(),
					query_schema: z.number(),
				}),

				// Derived indexes
				create_derived_index({
					key: 'recent_boolean_a_true',
					compute: (collection) => {
						const filtered_items = [];
						for (const item of collection.by_id.values()) {
							if (item.boolean_a) {
								filtered_items.push(item);
							}
						}
						return filtered_items
							.sort((a, b) => b.date_a.getTime() - a.date_a.getTime())
							.slice(0, 5); // Top 5 recent boolean_a=true items
					},
					matches: (item) => item.boolean_a,
					onadd: (items, item) => {
						if (!item.boolean_a) return items;

						// Find the right position based on date_a (newer items first)
						const index = items.findIndex(
							(existing) => item.date_a.getTime() > existing.date_a.getTime(),
						);

						if (index === -1) {
							items.push(item);
						} else {
							items.splice(index, 0, item);
						}

						// Maintain max size
						if (items.length > 5) {
							items.length = 5;
						}
						return items;
					},
					onremove: (items, item) => {
						const index = items.findIndex((i) => i.id === item.id);
						if (index !== -1) {
							items.splice(index, 1);
						}
						return items;
					},
				}),
				create_derived_index({
					key: 'high_number_a',
					compute: (collection) => {
						const result = [];
						for (const item of collection.by_id.values()) {
							if (item.number_a >= 4) {
								result.push(item);
							}
						}
						return result;
					},
					matches: (item) => item.number_a >= 4,
					onadd: (items, item) => {
						if (item.number_a >= 4) {
							items.push(item);
						}
						return items;
					},
					onremove: (items, item) => {
						const index = items.findIndex((i) => i.id === item.id);
						if (index !== -1) {
							items.splice(index, 1);
						}
						return items;
					},
				}),
			],
		});

		// Create test items with simple names
		const now = Date.now();
		items = [
			create_test_item({
				string_a: 'a1',
				string_b: 'b1',
				array_a: ['tag1', 'tag2', 'tag3'],
				string_c: 'c1',
				date_a: new Date(now - 1000 * 60 * 60 * 24 * 10), // 10 days ago
				number_a: 4,
				boolean_a: true,
			}),
			create_test_item({
				string_a: 'a2',
				string_b: 'b2',
				array_a: ['tag1', 'tag4'],
				string_c: 'c1',
				date_a: new Date(now - 1000 * 60 * 60 * 24 * 20), // 20 days ago
				number_a: 5,
				boolean_a: true,
			}),
			create_test_item({
				string_a: 'b1',
				string_b: 'b1',
				array_a: ['tag2', 'tag5'],
				string_c: 'c2',
				date_a: new Date(now - 1000 * 60 * 60 * 24 * 5), // 5 days ago
				number_a: 4,
				boolean_a: false,
			}),
			create_test_item({
				string_a: 'other',
				string_b: 'b3',
				array_a: ['tag3', 'tag6'],
				string_c: 'c3',
				date_a: new Date(now - 1000 * 60 * 60 * 24 * 30), // 30 days ago
				number_a: 3,
				boolean_a: false,
			}),
			create_test_item({
				string_a: 'b2',
				string_b: 'b3',
				array_a: ['tag1', 'tag5'],
				string_c: 'c2',
				date_a: new Date(now - 1000 * 60 * 60 * 24 * 3), // 3 days ago
				number_a: 5,
				boolean_a: true,
			}),
		];

		// Add all items to the collection
		collection.add_many(items);
	});

	test('basic query operations', () => {
		// Single index direct lookup
		expect(collection.by_optional('by_string_a', 'a1'.toLowerCase())).toBe(items[0]);
		expect(collection.by_optional('by_string_b', 'b1')).toBeDefined();

		// Multi index direct lookup
		expect(collection.where('by_string_c', 'c1')).toHaveLength(2);
		expect(collection.where('by_number_a', 5)).toHaveLength(2);
		expect(collection.where('by_boolean_a', 'y')).toHaveLength(3);

		// Non-existent values
		expect(collection.by_optional('by_string_a', 'nonexistent')).toBeUndefined();
		expect(collection.where('by_string_c', 'nonexistent')).toHaveLength(0);
	});

	test('case sensitivity in queries', () => {
		// Case insensitive string_a lookup (extractor converts to lowercase)
		expect(collection.by_optional('by_string_a', 'a1'.toLowerCase())).toBe(items[0]);
		expect(collection.by_optional('by_string_a', 'A1'.toLowerCase())).toBe(items[0]);

		// Case sensitive string_b lookup (no conversion in extractor)
		expect(collection.by_optional('by_string_b', 'B1')).toBeUndefined();
		expect(collection.by_optional('by_string_b', 'b1')).toBeDefined();
	});

	test('compound queries combining indexes', () => {
		// Find c1 items with string_b=b1
		const c1_items = collection.where('by_string_c', 'c1');
		const b1_c1_items = c1_items.filter((item) => item.string_b === 'b1');
		expect(b1_c1_items).toHaveLength(1);
		expect(b1_c1_items[0]!.string_a).toBe('a1');

		// Find boolean_a=true items with number_a=5
		const boolean_a_true_items = collection.where('by_boolean_a', 'y');
		const high_value_boolean_a_true = boolean_a_true_items.filter((item) => item.number_a === 5);
		expect(high_value_boolean_a_true).toHaveLength(2);
		expect(high_value_boolean_a_true.map((i) => i.string_a)).toContain('a2');
		expect(high_value_boolean_a_true.map((i) => i.string_a)).toContain('b2');
	});

	test('queries with array values', () => {
		// Query by array_a (checks if any tag matches)
		const tag1_items = collection.where('by_array_a', 'tag1');
		expect(tag1_items).toHaveLength(3);
		expect(tag1_items.map((i) => i.string_a)).toContain('a1');
		expect(tag1_items.map((i) => i.string_a)).toContain('a2');
		expect(tag1_items.map((i) => i.string_a)).toContain('b2');

		// Multiple tags intersection (using multiple queries)
		const tag2_items = collection.where('by_array_a', 'tag2');
		const tag2_and_tag3_items = tag2_items.filter((item) => item.array_a.includes('tag3'));
		expect(tag2_and_tag3_items).toHaveLength(1);
		expect(tag2_and_tag3_items[0]!.string_a).toBe('a1');
	});

	test('derived index queries', () => {
		// Test the recent_boolean_a_true derived index
		const recent_boolean_a_true = collection.derived_index('recent_boolean_a_true');
		expect(recent_boolean_a_true).toHaveLength(3); // All boolean_a=true items

		// Verify order (most recent first)
		const rbt0 = recent_boolean_a_true[0];
		const rbt1 = recent_boolean_a_true[1];
		const rbt2 = recent_boolean_a_true[2];
		expect(rbt0).toBeDefined();
		expect(rbt1).toBeDefined();
		expect(rbt2).toBeDefined();
		expect(rbt0!.string_a).toBe('b2'); // 3 days ago
		expect(rbt1!.string_a).toBe('a1'); // 10 days ago
		expect(rbt2!.string_a).toBe('a2'); // 20 days ago

		// Test the high_number_a derived index which should include all items with number_a >= 4
		const high_number_a = collection.derived_index('high_number_a');
		expect(high_number_a).toHaveLength(4);
		expect(high_number_a.map((i) => i.string_a).sort()).toEqual(['a1', 'a2', 'b1', 'b2'].sort());
	});

	test('first/latest with multi-index', () => {
		// Get first c1 item
		const first_c1 = collection.first('by_string_c', 'c1', 1);
		expect(first_c1).toHaveLength(1);
		const first_c1_item = first_c1[0];
		expect(first_c1_item).toBeDefined();

		// Get latest c2 item
		const latest_c2 = collection.latest('by_string_c', 'c2', 1);
		expect(latest_c2).toHaveLength(1);
		const latest_c2_item = latest_c2[0];
		expect(latest_c2_item).toBeDefined();
	});

	test('time-based queries', () => {
		// Query by year
		const current_year = new Date().getFullYear();
		const this_year_items = collection.where('by_year', current_year);

		const items_this_year_count = collection.values.filter(
			(item) => item.date_a.getFullYear() === current_year,
		).length;
		expect(this_year_items.length).toBe(items_this_year_count);

		// More complex date range query - last 7 days
		const now = Date.now();
		const recent_items = collection.values.filter(
			(item) => item.date_a.getTime() > now - 1000 * 60 * 60 * 24 * 7,
		);
		expect(recent_items.map((i) => i.string_a)).toContain('b1'); // 5 days ago
		expect(recent_items.map((i) => i.string_a)).toContain('b2'); // 3 days ago
	});

	test('adding items affects derived queries correctly', () => {
		// Add a new boolean_a=true item with high number_a
		const new_item = create_test_item({
			string_a: 'new',
			string_b: 'b4',
			array_a: ['tag7'],
			string_c: 'c4',
			date_a: new Date(), // Now (most recent)
			number_a: 5,
			boolean_a: true,
		});

		collection.add(new_item);

		// Check that it appears at the top of the recent_boolean_a_true list
		const recent_boolean_a_true = collection.derived_index('recent_boolean_a_true');
		expect(recent_boolean_a_true[0]!.id).toBe(new_item.id);

		// Check that it appears in high_number_a
		const high_number_a = collection.derived_index('high_number_a');
		expect(has_item_with_id(high_number_a, new_item)).toBe(true);
	});

	test('removing items updates derived queries', () => {
		// Remove the most recent boolean_a=true item
		const item_to_remove = items[4]; // b2 (most recent boolean_a=true)
		expect(item_to_remove).toBeDefined();

		collection.remove(item_to_remove!.id);

		// Check that recent_boolean_a_true updates correctly
		const recent_boolean_a_true = collection.derived_index('recent_boolean_a_true');
		expect(recent_boolean_a_true).toHaveLength(2);
		const rbt0 = recent_boolean_a_true[0];
		const rbt1 = recent_boolean_a_true[1];
		expect(rbt0).toBeDefined();
		expect(rbt1).toBeDefined();
		expect(rbt0!.string_a).toBe('a1');
		expect(rbt1!.string_a).toBe('a2');

		// Check that high_number_a updates correctly
		const high_number_a = collection.derived_index('high_number_a');
		expect(high_number_a).not.toContain(item_to_remove);
		expect(high_number_a).toHaveLength(3); // Started with 4, removed 1
	});

	test('dynamic ordering of query results', () => {
		// Get all items and sort by number_a (highest first)
		const sorted_by_number_a = collection.values.slice().sort((a, b) => b.number_a - a.number_a);
		expect(sorted_by_number_a[0]!.number_a).toBe(5);

		// Sort by creation time (newest first)
		const sorted_by_time = collection.values
			.slice()
			.sort((a, b) => b.date_a.getTime() - a.date_a.getTime());
		expect(sorted_by_time[0]!.string_a).toBe('b2'); // 3 days ago
	});
});

describe('IndexedCollection - Search Patterns', () => {
	let collection: IndexedCollection<TestItem>;

	beforeEach(() => {
		collection = new IndexedCollection<TestItem>({
			indexes: [
				// Word-based index that splits string_a into words for searching
				create_multi_index({
					key: 'by_word',
					extractor: (item) => item.string_a.toLowerCase().split(/\s+/),
					query_schema: z.string(),
				}),

				// Range-based categorization
				create_multi_index({
					key: 'by_number_a_range',
					extractor: (item) => {
						if (item.number_a <= 2) return 'low';
						if (item.number_a <= 4) return 'mid';
						return 'high';
					},
					query_schema: z.enum(['low', 'mid', 'high']),
				}),
			],
		});

		const test_items = [
			create_test_item({
				string_a: 'alpha beta gamma',
				number_a: 5,
			}),
			create_test_item({
				string_a: 'alpha delta',
				number_a: 4,
			}),
			create_test_item({
				string_a: 'beta epsilon',
				number_a: 3,
			}),
			create_test_item({
				string_a: 'gamma delta',
				number_a: 2,
			}),
		];

		collection.add_many(test_items);
	});

	test('word-based search', () => {
		// Find items with "alpha" in string_a
		const alpha_items = collection.where('by_word', 'alpha');
		expect(alpha_items).toHaveLength(2);

		// Find items with "beta" in string_a
		const beta_items = collection.where('by_word', 'beta');
		expect(beta_items).toHaveLength(2);

		// Find items with both "alpha" and "beta" (intersection)
		const alpha_beta_items = alpha_items.filter((item) =>
			item.string_a.toLowerCase().includes('beta'),
		);
		expect(alpha_beta_items).toHaveLength(1);
		expect(alpha_beta_items[0]!.string_a).toBe('alpha beta gamma');
	});

	test('range-based categorization', () => {
		// Find high-number_a items
		const high_number_a = collection.where('by_number_a_range', 'high');
		expect(high_number_a).toHaveLength(1);
		expect(high_number_a[0]!.number_a).toBe(5);

		// Find mid-number_a items
		const mid_number_a = collection.where('by_number_a_range', 'mid');
		expect(mid_number_a).toHaveLength(2);

		// Find low-number_a items
		const low_number_a = collection.where('by_number_a_range', 'low');
		expect(low_number_a).toHaveLength(1);
		expect(low_number_a[0]!.number_a).toBe(2);
	});
});
