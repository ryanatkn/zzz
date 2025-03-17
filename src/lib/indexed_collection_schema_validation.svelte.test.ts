// @vitest-environment jsdom

import {test, expect, describe, vi} from 'vitest';
import {z} from 'zod';

import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {
	create_single_index,
	create_multi_index,
	create_derived_index,
	create_dynamic_index,
} from '$lib/indexed_collection_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';

/* eslint-disable @typescript-eslint/no-empty-function */

// Test item type with various field types for schema validation
interface Test_Item {
	id: Uuid;
	a: string;
	b: string;
	c: number;
	d: boolean;
	e: Array<string>;
	f: {
		g: 'x' | 'y';
		h: boolean;
	};
}

// Helper function to create test items
const create_item = (
	a: string,
	b: string,
	c: number,
	d: boolean = true,
	e: Array<string> = ['e1'],
	g: 'x' | 'y' = 'x',
): Test_Item => ({
	id: Uuid.parse(undefined),
	a,
	b,
	c,
	d,
	e,
	f: {
		g,
		h: true,
	},
});

// Define schemas for validation
const item_schema = z.custom<Test_Item>((val) => val && typeof val === 'object' && 'id' in val);
const items_array_schema = z.array(item_schema);
const email_schema = z.string().email();
const range_schema = z.number().int().min(10).max(100);
const str_schema = z.string().min(1);

describe('Indexed_Collection - Schema Validation', () => {
	test('single index with schema validation', () => {
		// Create a collection with validation enabled
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_b',
					extractor: (item) => item.b,
					query_schema: email_schema,
					result_schema: z.map(z.string().email(), item_schema),
				}),
				create_single_index({
					key: 'by_a',
					extractor: (item) => item.a,
					query_schema: z.string(),
				}),
			],
			validate: true, // Enable schema validation
		});

		// Should accept valid data
		const item1 = create_item('a1', 'a1@example.com', 25);
		const item2 = create_item('a2', 'a2@example.com', 30);

		collection.add(item1);
		collection.add(item2);

		// Test query with valid email
		const query_result = collection.query<Test_Item, string>('by_b', 'a1@example.com');
		expect(query_result.a).toBe('a1');

		// Get single index and check schema validation passed
		const email_index = collection.single_index<Test_Item>('by_b');
		expect(email_index.size).toBe(2);
	});

	test('multi index with schema validation', () => {
		// Create spy to check console errors
		const console_error_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_multi_index({
					key: 'by_e',
					extractor: (item) => item.e,
					query_schema: str_schema,
				}),
				create_multi_index({
					key: 'by_c_range',
					extractor: (item) => {
						if (item.c < 20) return 'low';
						if (item.c < 50) return 'mid';
						return 'high';
					},
					query_schema: z.enum(['low', 'mid', 'high']),
				}),
			],
			validate: true,
		});

		// Add items across different ranges
		collection.add(create_item('a1', 'b1@test.com', 15, true, ['e1', 'e2']));
		collection.add(create_item('a2', 'b2@test.com', 30, true, ['e1', 'e3']));
		collection.add(create_item('a3', 'b3@test.com', 60, true, ['e2', 'e4']));
		collection.add(create_item('a4', 'b4@test.com', 90, true, ['e3', 'e4']));

		// Test range query validation
		const mid_items = collection.query<Array<Test_Item>, string>('by_c_range', 'mid');
		expect(mid_items.length).toBe(1);
		expect(mid_items[0].a).toBe('a2');

		// Test e index
		const e2_items = collection.query<Array<Test_Item>, string>('by_e', 'e2');
		expect(e2_items.length).toBe(2);
		expect(e2_items.some((item) => item.a === 'a1')).toBe(true);
		expect(e2_items.some((item) => item.a === 'a3')).toBe(true);

		const e3_items = collection.query<Array<Test_Item>, string>('by_e', 'e3');
		expect(e3_items.length).toBe(2);
		expect(e3_items.some((item) => item.a === 'a2')).toBe(true);
		expect(e3_items.some((item) => item.a === 'a4')).toBe(true);

		// Restore console.error
		console_error_spy.mockRestore();
	});

	test('derived index with schema validation', () => {
		// Create collection with derived index using schemas
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_derived_index({
					key: 'd_items',
					compute: (collection) => collection.all.filter((item) => item.d && item.c >= 18),
					matches: (item) => item.d && item.c >= 18,
					query_schema: z.void(),
					result_schema: items_array_schema,
				}),
			],
			validate: true,
		});

		// Add mix of items with different d/c values
		collection.add(create_item('a1', 'b1@test.com', 25, true)); // d=true, c>=18
		collection.add(create_item('a2', 'b2@test.com', 30, false)); // d=false, c>=18
		collection.add(create_item('a3', 'b3@test.com', 16, true)); // d=true, c<18
		collection.add(create_item('a4', 'b4@test.com', 17, false)); // d=false, c<18

		// Check derived index correctness
		const d_items = collection.get_derived('d_items');
		expect(d_items.length).toBe(1);
		expect(d_items[0].a).toBe('a1');

		// Add another qualifying item and verify index updates
		collection.add(create_item('a5', 'b5@test.com', 40, true));
		expect(collection.get_derived('d_items').length).toBe(2);
	});

	test('dynamic index with schema validation', () => {
		// Define schemas for dynamic function
		const query_schema = z.object({
			min_c: z.number().optional(),
			max_c: z.number().optional(),
			only_d: z.boolean().optional(),
			e_vals: z.array(z.string()).optional(),
		});

		type Item_Query = z.infer<typeof query_schema>;

		const result_schema = z.function().args(query_schema).returns(items_array_schema);

		// Create a dynamic index with complex query parameters
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_dynamic_index<Test_Item, (query: Item_Query) => Array<Test_Item>>({
					key: 'item_search',
					factory: (collection) => {
						return (query: Item_Query) => {
							return collection.all.filter((item) => {
								// Filter by c range if specified
								if (query.min_c !== undefined && item.c < query.min_c) return false;
								if (query.max_c !== undefined && item.c > query.max_c) return false;

								// Filter by d status if specified
								if (query.only_d !== undefined && query.only_d && !item.d) return false;

								// Filter by e if specified
								if (query.e_vals !== undefined && query.e_vals.length > 0) {
									const has_match = query.e_vals.some((v) => item.e.includes(v));
									if (!has_match) return false;
								}

								return true;
							});
						};
					},
					query_schema,
					result_schema,
				}),
			],
			validate: true,
		});

		// Add various items
		collection.add(create_item('a1', 'b1@test.com', 25, true, ['e1', 'e2']));
		collection.add(create_item('a2', 'b2@test.com', 35, true, ['e3', 'e4']));
		collection.add(create_item('a3', 'b3@test.com', 18, false, ['e2']));
		collection.add(create_item('a4', 'b4@test.com', 45, true, ['e1', 'e3', 'e5']));
		collection.add(create_item('a5', 'b5@test.com', 16, true, ['e4']));

		// Get the dynamic search function
		const search_fn = collection.get_index<(query: Item_Query) => Array<Test_Item>>('item_search');

		// Test c range query
		const young_range = search_fn({min_c: 18, max_c: 30});
		expect(young_range.length).toBe(2);
		expect(young_range.map((item) => item.a).sort()).toEqual(['a1', 'a3']);

		// Test d with specific e values
		const d_with_e1 = search_fn({only_d: true, e_vals: ['e1']});
		expect(d_with_e1.length).toBe(2);
		expect(d_with_e1.map((item) => item.a).sort()).toEqual(['a1', 'a4']);

		// Test items over 30 that are d with specific e values
		const high_c_with_e3 = search_fn({min_c: 30, only_d: true, e_vals: ['e3']});
		expect(high_c_with_e3.length).toBe(2);
		expect(high_c_with_e3.map((item) => item.a).sort()).toEqual(['a2', 'a4']);

		// Test using query method
		const with_e5 = collection.query<Array<Test_Item>, Item_Query>('item_search', {
			e_vals: ['e5'],
		});
		expect(with_e5.length).toBe(1);
		expect(with_e5[0].a).toBe('a4');
	});

	test('error handling when schema validation fails', () => {
		// Mock console.error to catch validation errors
		const console_error_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

		// Create collection with validation
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_b',
					extractor: (item) => item.b,
					query_schema: email_schema,
				}),
				create_single_index({
					key: 'by_c',
					extractor: (item) => item.c,
					query_schema: range_schema,
				}),
			],
			validate: true,
		});

		// Add items with valid data
		collection.add(create_item('a1', 'valid@example.com', 25));

		// Try querying with invalid email format
		collection.query('by_b', 'not-an-email');
		expect(console_error_spy).toHaveBeenCalledWith(
			expect.stringContaining('Query validation failed for index by_b'),
			expect.anything(),
		);

		// Try querying with out-of-range c
		collection.query('by_c', 5);
		expect(console_error_spy).toHaveBeenCalledWith(
			expect.stringContaining('Query validation failed for index by_c'),
			expect.anything(),
		);

		console_error_spy.mockRestore();
	});

	test('bypassing validation when validate flag is false', () => {
		// Mock console.error to verify no validation errors
		const console_error_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

		// Create collection without validation
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_b',
					extractor: (item) => item.b,
					query_schema: email_schema,
				}),
				create_single_index({
					key: 'by_c',
					extractor: (item) => item.c,
					query_schema: range_schema,
				}),
			],
			validate: false, // Explicitly disable validation
		});

		// Add items
		collection.add(create_item('a1', 'valid@example.com', 25));

		// These queries would fail validation, but should not trigger console errors
		collection.query('by_b', 'not-an-email');
		collection.query('by_c', 5);

		// Verify no validation errors were logged
		expect(console_error_spy).not.toHaveBeenCalled();

		console_error_spy.mockRestore();
	});

	test('validation with nested properties and complex types', () => {
		// Schema for nested property validation
		const f_schema = z.object({
			g: z.enum(['x', 'y']),
			h: z.boolean(),
		});

		// Create collection with complex validation
		const collection: Indexed_Collection<Test_Item> = new Indexed_Collection({
			indexes: [
				create_single_index({
					key: 'by_f_g',
					extractor: (item) => item.f.g,
					query_schema: f_schema.shape.g,
				}),
				create_multi_index({
					key: 'by_compound',
					extractor: (item) => {
						// Return a compound key made from multiple fields
						return `${item.a}-${item.f.g}`;
					},
					query_schema: z.string().regex(/^[a-z0-9]+-[xy]$/),
				}),
			],
			validate: true,
		});

		// Add items with valid nested properties
		const item1 = create_item('a1', 'b1@test.com', 25, true, ['e1'], 'x');
		const item2 = create_item('a2', 'b2@test.com', 35, true, ['e2'], 'y');

		collection.add(item1);
		collection.add(item2);

		// Test lookup by nested property - use by_optional instead of where for single index
		expect(collection.by_optional('by_f_g', 'x')?.a).toBe('a1');
		expect(collection.by_optional('by_f_g', 'y')?.a).toBe('a2');

		// Test compound key lookup
		expect(collection.where('by_compound', 'a1-x').length).toBe(1);
		expect(collection.where('by_compound', 'a2-y').length).toBe(1);
	});
});
