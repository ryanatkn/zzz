// @vitest-environment jsdom

import {test, expect, describe, beforeEach} from 'vitest';
import {z} from 'zod';

import {Indexed_Collection, type Indexed_Item} from '$lib/indexed_collection.svelte.js';
import {
	create_single_index,
	create_multi_index,
	create_derived_index,
} from '$lib/indexed_collection_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';

// Test item representing a generic item
interface Test_Item {
	id: Uuid;
	text: string;
	code: string;
	labels: Array<string>;
	group: string;
	time: Date;
	value: number;
	flag: boolean;
}

// Helper to create items with default values that can be overridden
const create_test_item = (overrides: Partial<Test_Item> = {}): Test_Item => ({
	id: Uuid.parse(undefined),
	text: 'text1',
	code: 'code1',
	labels: ['label1'],
	group: 'g1',
	time: new Date(),
	value: 3,
	flag: false,
	...overrides,
});

// Helper functions for ID-based object equality checks
const has_item_with_id = (array: Array<Indexed_Item>, item: Indexed_Item): boolean =>
	array.some((i) => i.id === item.id);

describe('Indexed_Collection - Query Capabilities', () => {
	let collection: Indexed_Collection<Test_Item>;
	let items: Array<Test_Item>;

	beforeEach(() => {
		// Create a collection with various indexes
		collection = new Indexed_Collection<Test_Item>({
			indexes: [
				// Single value indexes
				create_single_index({
					key: 'by_text',
					extractor: (item) => item.text.toLowerCase(), // Case insensitive
					query_schema: z.string(),
				}),
				create_single_index({
					key: 'by_code',
					extractor: (item) => item.code, // Case sensitive
					query_schema: z.string(),
				}),

				// Multi value indexes
				create_multi_index({
					key: 'by_group',
					extractor: (item) => item.group,
					query_schema: z.string(),
				}),
				create_multi_index({
					key: 'by_labels',
					extractor: (item) => item.labels,
					query_schema: z.string(),
				}),
				create_multi_index({
					key: 'by_value',
					extractor: (item) => item.value,
					query_schema: z.number(),
				}),
				create_multi_index({
					key: 'by_flag',
					extractor: (item) => (item.flag ? 'y' : 'n'),
					query_schema: z.enum(['y', 'n']),
				}),
				create_multi_index({
					key: 'by_year',
					extractor: (item) => item.time.getFullYear(),
					query_schema: z.number(),
				}),

				// Derived indexes
				create_derived_index({
					key: 'recent_flagged',
					compute: (collection) => {
						return collection.all
							.filter((item) => item.flag)
							.sort((a, b) => b.time.getTime() - a.time.getTime())
							.slice(0, 5); // Top 5 recent flag=true items
					},
					matches: (item) => item.flag,
					on_add: (items, item) => {
						if (!item.flag) return items;

						// Find the right position based on time (newer items first)
						const index = items.findIndex(
							(existing) => item.time.getTime() > existing.time.getTime(),
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
					on_remove: (items, item) => {
						const index = items.findIndex((i) => i.id === item.id);
						if (index !== -1) {
							items.splice(index, 1);
						}
						return items;
					},
				}),
				create_derived_index({
					key: 'high_value',
					compute: (collection) => collection.all.filter((item) => item.value >= 4),
					matches: (item) => item.value >= 4,
					on_add: (items, item) => {
						if (item.value >= 4) {
							items.push(item);
						}
						return items;
					},
					on_remove: (items, item) => {
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
				text: 'item1',
				code: 'code1',
				labels: ['label1', 'label2', 'label3'],
				group: 'g1',
				time: new Date(now - 1000 * 60 * 60 * 24 * 10), // 10 days ago
				value: 4,
				flag: true,
			}),
			create_test_item({
				text: 'item2',
				code: 'code2',
				labels: ['label1', 'label4'],
				group: 'g1',
				time: new Date(now - 1000 * 60 * 60 * 24 * 20), // 20 days ago
				value: 5,
				flag: true,
			}),
			create_test_item({
				text: 'code1',
				code: 'code1',
				labels: ['label2', 'label5'],
				group: 'g2',
				time: new Date(now - 1000 * 60 * 60 * 24 * 5), // 5 days ago
				value: 4,
				flag: false,
			}),
			create_test_item({
				text: 'other',
				code: 'code3',
				labels: ['label3', 'label6'],
				group: 'g3',
				time: new Date(now - 1000 * 60 * 60 * 24 * 30), // 30 days ago
				value: 3,
				flag: false,
			}),
			create_test_item({
				text: 'code2',
				code: 'code3',
				labels: ['label1', 'label5'],
				group: 'g2',
				time: new Date(now - 1000 * 60 * 60 * 24 * 3), // 3 days ago
				value: 5,
				flag: true,
			}),
		];

		// Add all items to the collection
		collection.add_many(items);
	});

	test('basic query operations', () => {
		// Single index direct lookup
		expect(collection.by_optional('by_text', 'item1'.toLowerCase())).toBe(items[0]);
		expect(collection.by_optional('by_code', 'code1')).toBeDefined();

		// Multi index direct lookup
		expect(collection.where('by_group', 'g1')).toHaveLength(2);
		expect(collection.where('by_value', 5)).toHaveLength(2);
		expect(collection.where('by_flag', 'y')).toHaveLength(3);

		// Non-existent values
		expect(collection.by_optional('by_text', 'nonexistent')).toBeUndefined();
		expect(collection.where('by_group', 'nonexistent')).toHaveLength(0);
	});

	test('case sensitivity in queries', () => {
		// Case insensitive text lookup (extractor converts to lowercase)
		expect(collection.by_optional('by_text', 'item1'.toLowerCase())).toBe(items[0]);
		expect(collection.by_optional('by_text', 'ITEM1'.toLowerCase())).toBe(items[0]);

		// Case sensitive code lookup (no conversion in extractor)
		expect(collection.by_optional('by_code', 'CODE1')).toBeUndefined();
		expect(collection.by_optional('by_code', 'code1')).toBeDefined();
	});

	test('compound queries combining indexes', () => {
		// Find g1 items by code1
		const g1_items = collection.where('by_group', 'g1');
		const code1_g1_items = g1_items.filter((item) => item.code === 'code1');
		expect(code1_g1_items).toHaveLength(1);
		expect(code1_g1_items[0].text).toBe('item1');

		// Find flag=true items with value=5
		const flagged_items = collection.where('by_flag', 'y');
		const high_value_flagged = flagged_items.filter((item) => item.value === 5);
		expect(high_value_flagged).toHaveLength(2);
		expect(high_value_flagged.map((i) => i.text)).toContain('item2');
		expect(high_value_flagged.map((i) => i.text)).toContain('code2');
	});

	test('queries with array values', () => {
		// Query by labels (checks if any label matches)
		const label1_items = collection.where('by_labels', 'label1');
		expect(label1_items).toHaveLength(3);
		expect(label1_items.map((i) => i.text)).toContain('item1');
		expect(label1_items.map((i) => i.text)).toContain('item2');
		expect(label1_items.map((i) => i.text)).toContain('code2');

		// Multiple labels intersection (using multiple queries)
		const label2_items = collection.where('by_labels', 'label2');
		const label2_and_label3_items = label2_items.filter((item) => item.labels.includes('label3'));
		expect(label2_and_label3_items).toHaveLength(1);
		expect(label2_and_label3_items[0].text).toBe('item1');
	});

	test('derived index queries', () => {
		// Test the recent_flagged derived index
		const recent_flagged = collection.get_derived('recent_flagged');
		expect(recent_flagged).toHaveLength(3); // All flag=true items

		// Verify order (most recent first)
		expect(recent_flagged[0].text).toBe('code2'); // 3 days ago
		expect(recent_flagged[1].text).toBe('item1'); // 10 days ago
		expect(recent_flagged[2].text).toBe('item2'); // 20 days ago

		// Test the high_value derived index which should include all items with value >= 4
		const high_value = collection.get_derived('high_value');
		expect(high_value).toHaveLength(4);
		expect(high_value.map((i) => i.text).sort()).toEqual(
			['item1', 'item2', 'code1', 'code2'].sort(),
		);
	});

	test('first/latest with multi-index', () => {
		// Get first g1 item
		const first_g1 = collection.first('by_group', 'g1', 1);
		expect(first_g1).toHaveLength(1);
		expect(first_g1[0].text).toBe('item1');

		// Get latest g2 item
		const latest_g2 = collection.latest('by_group', 'g2', 1);
		expect(latest_g2).toHaveLength(1);
		expect(latest_g2[0].text).toBe('code2');
	});

	test('time-based queries', () => {
		// Query by year
		const current_year = new Date().getFullYear();
		const this_year_items = collection.where('by_year', current_year);

		const items_this_year = collection.all.filter(
			(item) => item.time.getFullYear() === current_year,
		).length;
		expect(this_year_items.length).toBe(items_this_year);

		// More complex date range query - last 7 days
		const now = Date.now();
		const recent_items = collection.all.filter(
			(item) => item.time.getTime() > now - 1000 * 60 * 60 * 24 * 7,
		);
		expect(recent_items.map((i) => i.text)).toContain('code1'); // 5 days ago
		expect(recent_items.map((i) => i.text)).toContain('code2'); // 3 days ago
	});

	test('adding items affects derived queries correctly', () => {
		// Add a new flag=true item with high value
		const new_item = create_test_item({
			text: 'new',
			code: 'code4',
			labels: ['label7'],
			group: 'g4',
			time: new Date(), // Now (most recent)
			value: 5,
			flag: true,
		});

		collection.add(new_item);

		// Check that it appears at the top of the recent_flagged list
		const recent_flagged = collection.get_derived('recent_flagged');
		expect(recent_flagged[0].id).toBe(new_item.id);

		// Check that it appears in high_value
		const high_value = collection.get_derived('high_value');
		expect(has_item_with_id(high_value, new_item)).toBe(true);
	});

	test('removing items updates derived queries', () => {
		// Remove the most recent flag=true item
		const item_to_remove = items[4]; // code2 (most recent flag=true)

		collection.remove(item_to_remove.id);

		// Check that recent_flagged updates correctly
		const recent_flagged = collection.get_derived('recent_flagged');
		expect(recent_flagged).toHaveLength(2);
		expect(recent_flagged[0].text).toBe('item1');
		expect(recent_flagged[1].text).toBe('item2');

		// Check that high_value updates correctly
		const high_value = collection.get_derived('high_value');
		expect(high_value).not.toContain(item_to_remove);
		expect(high_value).toHaveLength(3); // Started with 4, removed 1
	});

	test('dynamic ordering of query results', () => {
		// Get all items and sort by value (highest first)
		const sorted_by_value = [...collection.all].sort((a, b) => b.value - a.value);
		expect(sorted_by_value[0].value).toBe(5);

		// Sort by creation time (newest first)
		const sorted_by_time = [...collection.all].sort((a, b) => b.time.getTime() - a.time.getTime());
		expect(sorted_by_time[0].text).toBe('code2'); // 3 days ago
	});
});

describe('Indexed_Collection - Search Patterns', () => {
	let collection: Indexed_Collection<Test_Item>;

	beforeEach(() => {
		collection = new Indexed_Collection<Test_Item>({
			indexes: [
				// Word-based index that splits text into words for searching
				create_multi_index({
					key: 'by_word',
					extractor: (item) => item.text.toLowerCase().split(/\s+/),
					query_schema: z.string(),
				}),

				// Range-based categorization
				create_multi_index({
					key: 'by_value_range',
					extractor: (item) => {
						if (item.value <= 2) return 'low';
						if (item.value <= 4) return 'mid';
						return 'high';
					},
					query_schema: z.enum(['low', 'mid', 'high']),
				}),
			],
		});

		const test_items = [
			create_test_item({
				text: 'alpha beta gamma',
				value: 5,
			}),
			create_test_item({
				text: 'alpha delta',
				value: 4,
			}),
			create_test_item({
				text: 'beta epsilon',
				value: 3,
			}),
			create_test_item({
				text: 'gamma delta',
				value: 2,
			}),
		];

		collection.add_many(test_items);
	});

	test('word-based search', () => {
		// Find items with "alpha" in text
		const alpha_items = collection.where('by_word', 'alpha');
		expect(alpha_items).toHaveLength(2);

		// Find items with "beta" in text
		const beta_items = collection.where('by_word', 'beta');
		expect(beta_items).toHaveLength(2);

		// Find items with both "alpha" and "beta" (intersection)
		const alpha_beta_items = alpha_items.filter((item) => item.text.toLowerCase().includes('beta'));
		expect(alpha_beta_items).toHaveLength(1);
		expect(alpha_beta_items[0].text).toBe('alpha beta gamma');
	});

	test('range-based categorization', () => {
		// Find high-value items
		const high_value = collection.where('by_value_range', 'high');
		expect(high_value).toHaveLength(1);
		expect(high_value[0].value).toBe(5);

		// Find mid-value items
		const mid_value = collection.where('by_value_range', 'mid');
		expect(mid_value).toHaveLength(2);

		// Find low-value items
		const low_value = collection.where('by_value_range', 'low');
		expect(low_value).toHaveLength(1);
		expect(low_value[0].value).toBe(2);
	});
});
