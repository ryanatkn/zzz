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
	a: string;
	b: string;
	c: Array<string>;
	d: string;
	e: Date;
	f: number;
	g: boolean;
}

// Helper to create items with default values that can be overridden
const create_item = (overrides: Partial<Test_Item> = {}): Test_Item => ({
	id: Uuid.parse(undefined),
	a: 'a1',
	b: 'b1',
	c: ['c1'],
	d: 'd1',
	e: new Date(),
	f: 3,
	g: false,
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
					key: 'by_a',
					extractor: (item) => item.a.toLowerCase(), // Case insensitive
					query_schema: z.string(),
				}),
				create_single_index({
					key: 'by_b',
					extractor: (item) => item.b, // Case sensitive
					query_schema: z.string(),
				}),

				// Multi value indexes
				create_multi_index({
					key: 'by_d',
					extractor: (item) => item.d,
					query_schema: z.string(),
				}),
				create_multi_index({
					key: 'by_c',
					extractor: (item) => item.c,
					query_schema: z.string(),
				}),
				create_multi_index({
					key: 'by_f',
					extractor: (item) => item.f,
					query_schema: z.number(),
				}),
				create_multi_index({
					key: 'by_g',
					extractor: (item) => (item.g ? 'y' : 'n'),
					query_schema: z.enum(['y', 'n']),
				}),
				create_multi_index({
					key: 'by_year',
					extractor: (item) => item.e.getFullYear(),
					query_schema: z.number(),
				}),

				// Derived indexes
				create_derived_index({
					key: 'g_recent',
					compute: (collection) => {
						return collection.all
							.filter((item) => item.g)
							.sort((a, b) => b.e.getTime() - a.e.getTime())
							.slice(0, 5); // Top 5 recent g=true items
					},
					matches: (item) => item.g,
					on_add: (items, item) => {
						if (!item.g) return items;

						// Find the right position based on date (newer items first)
						const index = items.findIndex((existing) => item.e.getTime() > existing.e.getTime());

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
					key: 'high_f',
					compute: (collection) => collection.all.filter((item) => item.f >= 4),
					matches: (item) => item.f >= 4,
					on_add: (items, item) => {
						if (item.f >= 4) {
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
			create_item({
				a: 'a1',
				b: 'b1',
				c: ['c1', 'c2', 'c3'],
				d: 'd1',
				e: new Date(now - 1000 * 60 * 60 * 24 * 10), // 10 days ago
				f: 4,
				g: true,
			}),
			create_item({
				a: 'a2',
				b: 'b2',
				c: ['c1', 'c4'],
				d: 'd1',
				e: new Date(now - 1000 * 60 * 60 * 24 * 20), // 20 days ago
				f: 5,
				g: true,
			}),
			create_item({
				a: 'b1',
				b: 'b1',
				c: ['c2', 'c5'],
				d: 'd2',
				e: new Date(now - 1000 * 60 * 60 * 24 * 5), // 5 days ago
				f: 4,
				g: false,
			}),
			create_item({
				a: 'c1',
				b: 'b3',
				c: ['c3', 'c6'],
				d: 'd3',
				e: new Date(now - 1000 * 60 * 60 * 24 * 30), // 30 days ago
				f: 3,
				g: false,
			}),
			create_item({
				a: 'b2',
				b: 'b3',
				c: ['c1', 'c5'],
				d: 'd2',
				e: new Date(now - 1000 * 60 * 60 * 24 * 3), // 3 days ago
				f: 5,
				g: true,
			}),
		];

		// Add all items to the collection
		collection.add_many(items);
	});

	test('basic query operations', () => {
		// Single index direct lookup
		expect(collection.by_optional('by_a', 'a1'.toLowerCase())).toBe(items[0]);
		expect(collection.by_optional('by_b', 'b1')).toBeDefined();

		// Multi index direct lookup
		expect(collection.where('by_d', 'd1')).toHaveLength(2);
		expect(collection.where('by_f', 5)).toHaveLength(2);
		expect(collection.where('by_g', 'y')).toHaveLength(3);

		// Non-existent values
		expect(collection.by_optional('by_a', 'nonexistent')).toBeUndefined();
		expect(collection.where('by_d', 'nonexistent')).toHaveLength(0);
	});

	test('case sensitivity in queries', () => {
		// Case insensitive a lookup (extractor converts to lowercase)
		expect(collection.by_optional('by_a', 'a1'.toLowerCase())).toBe(items[0]);
		expect(collection.by_optional('by_a', 'A1'.toLowerCase())).toBe(items[0]);

		// Case sensitive b lookup (no conversion in extractor)
		expect(collection.by_optional('by_b', 'B1')).toBeUndefined();
		expect(collection.by_optional('by_b', 'b1')).toBeDefined();
	});

	test('compound queries combining indexes', () => {
		// Find d1 items by b1
		const d1_items = collection.where('by_d', 'd1');
		const b1_d1_items = d1_items.filter((item) => item.b === 'b1');
		expect(b1_d1_items).toHaveLength(1);
		expect(b1_d1_items[0].a).toBe('a1');

		// Find g=true items with f=5
		const g_true_items = collection.where('by_g', 'y');
		const high_f_g_true = g_true_items.filter((item) => item.f === 5);
		expect(high_f_g_true).toHaveLength(2);
		expect(high_f_g_true.map((i) => i.a)).toContain('a2');
		expect(high_f_g_true.map((i) => i.a)).toContain('b2');
	});

	test('queries with array values', () => {
		// Query by c (checks if any c matches)
		const c1_items = collection.where('by_c', 'c1');
		expect(c1_items).toHaveLength(3);
		expect(c1_items.map((i) => i.a)).toContain('a1');
		expect(c1_items.map((i) => i.a)).toContain('a2');
		expect(c1_items.map((i) => i.a)).toContain('b2');

		// Multiple c intersection (using multiple queries)
		const c2_items = collection.where('by_c', 'c2');
		const c2_and_c3_items = c2_items.filter((item) => item.c.includes('c3'));
		expect(c2_and_c3_items).toHaveLength(1);
		expect(c2_and_c3_items[0].a).toBe('a1');
	});

	test('derived index queries', () => {
		// Test the g_recent derived index
		const recent_g = collection.get_derived('g_recent');
		expect(recent_g).toHaveLength(3); // All g=true items

		// Verify order (most recent first)
		expect(recent_g[0].a).toBe('b2'); // 3 days ago
		expect(recent_g[1].a).toBe('a1'); // 10 days ago
		expect(recent_g[2].a).toBe('a2'); // 20 days ago

		// Test the high_f derived index which should include all items with f >= 4
		const high_f = collection.get_derived('high_f');
		expect(high_f).toHaveLength(4);
		expect(high_f.map((i) => i.a).sort()).toEqual(['a1', 'a2', 'b1', 'b2'].sort());
	});

	test('first/latest with multi-index', () => {
		// Get first d1 item
		const first_d1 = collection.first('by_d', 'd1', 1);
		expect(first_d1).toHaveLength(1);
		expect(first_d1[0].a).toBe('a1');

		// Get latest d2 item
		const latest_d2 = collection.latest('by_d', 'd2', 1);
		expect(latest_d2).toHaveLength(1);
		expect(latest_d2[0].a).toBe('b2');
	});

	test('time-based queries', () => {
		// Query by year
		const current_year = new Date().getFullYear();
		const this_year_items = collection.where('by_year', current_year);

		const items_this_year = collection.all.filter(
			(item) => item.e.getFullYear() === current_year,
		).length;
		expect(this_year_items.length).toBe(items_this_year);

		// More complex date range query - last 7 days
		const now = Date.now();
		const recent_items = collection.all.filter(
			(item) => item.e.getTime() > now - 1000 * 60 * 60 * 24 * 7,
		);
		expect(recent_items.map((i) => i.a)).toContain('b1'); // 5 days ago
		expect(recent_items.map((i) => i.a)).toContain('b2'); // 3 days ago
	});

	test('adding items affects derived queries correctly', () => {
		// Add a new g=true item with high f
		const new_item = create_item({
			a: 'd1',
			b: 'b4',
			c: ['c7'],
			d: 'd4',
			e: new Date(), // Now (most recent)
			f: 5,
			g: true,
		});

		collection.add(new_item);

		// Check that it appears at the top of the g_recent list
		const recent_g = collection.get_derived('g_recent');
		expect(recent_g[0].id).toBe(new_item.id);

		// Check that it appears in high_f
		const high_f = collection.get_derived('high_f');
		expect(has_item_with_id(high_f, new_item)).toBe(true);
	});

	test('removing items updates derived queries', () => {
		// Remove the most recent g=true item
		const item_to_remove = items[4]; // b2 (most recent g=true)

		collection.remove(item_to_remove.id);

		// Check that g_recent updates correctly
		const recent_g = collection.get_derived('g_recent');
		expect(recent_g).toHaveLength(2);
		expect(recent_g[0].a).toBe('a1');
		expect(recent_g[1].a).toBe('a2');

		// Check that high_f updates correctly
		const high_f = collection.get_derived('high_f');
		expect(high_f).not.toContain(item_to_remove);
		expect(high_f).toHaveLength(3); // Started with 4, removed 1
	});

	test('dynamic ordering of query results', () => {
		// Get all items and sort by f (highest first)
		const sorted_by_f = [...collection.all].sort((a, b) => b.f - a.f);
		expect(sorted_by_f[0].f).toBe(5);

		// Sort by creation date (newest first)
		const sorted_by_date = [...collection.all].sort((a, b) => b.e.getTime() - a.e.getTime());
		expect(sorted_by_date[0].a).toBe('b2'); // 3 days ago
	});
});

describe('Indexed_Collection - Search Patterns', () => {
	let collection: Indexed_Collection<Test_Item>;

	beforeEach(() => {
		collection = new Indexed_Collection<Test_Item>({
			indexes: [
				// Word-based index that splits a into words for searching
				create_multi_index({
					key: 'by_word',
					extractor: (item) => item.a.toLowerCase().split(/\s+/),
					query_schema: z.string(),
				}),

				// Range-based categorization
				create_multi_index({
					key: 'by_f_range',
					extractor: (item) => {
						if (item.f <= 2) return 'low';
						if (item.f <= 4) return 'mid';
						return 'high';
					},
					query_schema: z.enum(['low', 'mid', 'high']),
				}),
			],
		});

		const test_items = [
			create_item({
				a: 'x y z',
				f: 5,
			}),
			create_item({
				a: 'x w',
				f: 4,
			}),
			create_item({
				a: 'y v',
				f: 3,
			}),
			create_item({
				a: 'z w',
				f: 2,
			}),
		];

		collection.add_many(test_items);
	});

	test('word-based search', () => {
		// Find items with "x" in a
		const x_items = collection.where('by_word', 'x');
		expect(x_items).toHaveLength(2);

		// Find items with "y" in a
		const y_items = collection.where('by_word', 'y');
		expect(y_items).toHaveLength(2);

		// Find items with both "x" and "y" (intersection)
		const x_y_items = x_items.filter((item) => item.a.toLowerCase().includes('y'));
		expect(x_y_items).toHaveLength(1);
		expect(x_y_items[0].a).toBe('x y z');
	});

	test('range-based categorization', () => {
		// Find high-f items
		const high_f = collection.where('by_f_range', 'high');
		expect(high_f).toHaveLength(1);
		expect(high_f[0].f).toBe(5);

		// Find mid-f items
		const mid_f = collection.where('by_f_range', 'mid');
		expect(mid_f).toHaveLength(2);

		// Find low-f items
		const low_f = collection.where('by_f_range', 'low');
		expect(low_f).toHaveLength(1);
		expect(low_f[0].f).toBe(2);
	});
});
