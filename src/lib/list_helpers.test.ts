import {test, expect, describe} from 'vitest';
import {reorder_list, to_reordered_list} from '$lib/list_helpers.js';

// Test constants
const SAMPLE_ARRAY = ['a', 'b', 'c', 'd', 'e'];
const SINGLE_ITEM_ARRAY = ['only'];
const EMPTY_ARRAY: Array<string> = [];

describe('reorder_list', () => {
	// Basic functionality tests
	test('moves an item forward in the array', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 1, 3);
		expect(array).toEqual(['a', 'c', 'd', 'b', 'e']);
	});

	test('moves an item backward in the array', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 3, 1);
		expect(array).toEqual(['a', 'd', 'b', 'c', 'e']);
	});

	test('does nothing when from_index equals to_index', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 2, 2);
		expect(array).toEqual(SAMPLE_ARRAY);
	});

	// Edge cases
	test('moves first item to the end', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 0, 5);
		expect(array).toEqual(['b', 'c', 'd', 'e', 'a']);
	});

	test('moves first item one position forward', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 0, 1);
		expect(array).toEqual(['b', 'a', 'c', 'd', 'e']);
	});

	test('moves last item to the beginning', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 4, 0);
		expect(array).toEqual(['e', 'a', 'b', 'c', 'd']);
	});

	test('moves last item one position backward', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 4, 3);
		expect(array).toEqual(['a', 'b', 'c', 'e', 'd']);
	});

	test('handles single item array correctly', () => {
		const array = [...SINGLE_ITEM_ARRAY];
		reorder_list(array, 0, 0);
		expect(array).toEqual(SINGLE_ITEM_ARRAY);
	});

	test('handles empty array correctly', () => {
		const array = [...EMPTY_ARRAY];
		reorder_list(array, 0, 0);
		expect(array).toEqual(EMPTY_ARRAY);
	});

	// Error cases - testing that array remains unchanged with invalid indices
	test('handles negative from_index by leaving array unchanged', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, -1, 2);
		expect(array).toEqual(SAMPLE_ARRAY);
	});

	test('handles out of bounds from_index by leaving array unchanged', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 10, 2);
		expect(array).toEqual(SAMPLE_ARRAY);
	});

	test('handles negative to_index by leaving array unchanged', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 2, -1);
		expect(array).toEqual(SAMPLE_ARRAY);
	});

	test('handles out of bounds to_index by leaving array unchanged', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 2, 10);
		expect(array).toEqual(SAMPLE_ARRAY);
	});

	test('moves item to exact length boundary', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 2, array.length);
		expect(array).toEqual(['a', 'b', 'd', 'e', 'c']);
	});

	test('handles adjacent indices correctly when moving forward', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 1, 2);
		expect(array).toEqual(['a', 'c', 'b', 'd', 'e']);
	});

	test('handles adjacent indices correctly when moving backward', () => {
		const array = [...SAMPLE_ARRAY];
		reorder_list(array, 2, 1);
		expect(array).toEqual(['a', 'c', 'b', 'd', 'e']);
	});
});

describe('to_reordered_list', () => {
	// Basic functionality tests
	test('creates new array with item moved forward', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 1, 3);
		expect(result).toEqual(['a', 'c', 'd', 'b', 'e']);
		expect(original).toEqual(SAMPLE_ARRAY); // Original unchanged
	});

	test('creates new array with item moved backward', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 3, 1);
		expect(result).toEqual(['a', 'd', 'b', 'c', 'e']);
		expect(original).toEqual(SAMPLE_ARRAY); // Original unchanged
	});

	test('returns original array when from_index equals to_index', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 2, 2);
		expect(result).toBe(original); // Same reference, not just equal
	});

	// Edge cases
	test('creates new array with first item moved to end', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 0, 5);
		expect(result).toEqual(['b', 'c', 'd', 'e', 'a']);
		expect(original).toEqual(SAMPLE_ARRAY); // Original unchanged
	});

	test('creates new array with first item moved one position forward', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 0, 1);
		expect(result).toEqual(['b', 'a', 'c', 'd', 'e']);
		expect(original).toEqual(SAMPLE_ARRAY); // Original unchanged
	});

	test('creates new array with last item moved to beginning', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 4, 0);
		expect(result).toEqual(['e', 'a', 'b', 'c', 'd']);
		expect(original).toEqual(SAMPLE_ARRAY); // Original unchanged
	});

	test('creates new array with last item moved one position backward', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 4, 3);
		expect(result).toEqual(['a', 'b', 'c', 'e', 'd']);
		expect(original).toEqual(SAMPLE_ARRAY); // Original unchanged
	});

	test('handles single item array correctly', () => {
		const original = [...SINGLE_ITEM_ARRAY];
		const result = to_reordered_list(original, 0, 0);
		expect(result).toBe(original); // Same reference
	});

	test('handles empty array correctly', () => {
		const original = [...EMPTY_ARRAY];
		const result = to_reordered_list(original, 0, 0);
		expect(result).toBe(original); // Same reference
	});

	// Error cases - testing that original array is returned with invalid indices
	test('handles negative from_index by returning original array', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, -1, 2);
		expect(result).toBe(original);
	});

	test('handles out of bounds from_index by returning original array', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 10, 2);
		expect(result).toBe(original);
	});

	test('handles negative to_index by returning original array', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 2, -1);
		expect(result).toBe(original);
	});

	test('handles out of bounds to_index by returning original array', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 2, 10);
		expect(result).toBe(original);
	});

	test('creates new array with item moved to exact length boundary', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 2, original.length);
		expect(result).toEqual(['a', 'b', 'd', 'e', 'c']);
		expect(original).toEqual(SAMPLE_ARRAY); // Original unchanged
	});

	test('creates new array with adjacent indices correctly when moving forward', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 1, 2);
		expect(result).toEqual(['a', 'c', 'b', 'd', 'e']);
		expect(original).toEqual(SAMPLE_ARRAY); // Original unchanged
	});

	test('creates new array with adjacent indices correctly when moving backward', () => {
		const original = [...SAMPLE_ARRAY];
		const result = to_reordered_list(original, 2, 1);
		expect(result).toEqual(['a', 'c', 'b', 'd', 'e']);
		expect(original).toEqual(SAMPLE_ARRAY); // Original unchanged
	});
});
