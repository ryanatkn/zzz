// @vitest-environment jsdom
import {test, expect, describe, beforeEach} from 'vitest';
import {z} from 'zod';

import {Sortable, type Sorter, sort_by_text, sort_by_numeric} from '$lib/sortable.svelte.js';
import {Cell} from '$lib/cell.svelte.js';
import {Uuid_With_Default, type Uuid, Datetime_Now, create_uuid} from '$lib/zod_helpers.js';
import {Zzz} from '$lib/zzz.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Create a schema for our test cell
const Test_Cell_Schema = z.object({
	id: Uuid_With_Default,
	created: Datetime_Now,
	updated: Datetime_Now,
	name: z.string(),
	value: z.number(),
});

// Real cell class for testing - extends the Cell base class
class Test_Cell extends Cell<typeof Test_Cell_Schema> {
	name: string = $state('');
	value: number = $state(0);

	constructor(zzz: Zzz, id: Uuid, name: string, value: number, override_cid?: number) {
		super(Test_Cell_Schema, {
			zzz,
			json: {
				id,
				created: new Date().toISOString(),
				updated: new Date().toISOString(),
				name,
				value,
			},
		});

		// Allow test to override the monotonic cid for testing sorting behavior
		if (override_cid !== undefined) {
			(this as any).cid = override_cid;
		}

		this.init();
	}
}

describe('Sortable', () => {
	let items: Array<Test_Cell>;
	let sorters: Array<Sorter<Test_Cell>>;
	let zzz: Zzz;

	// Create test UUIDs - using proper UUIDs instead of simple strings
	const id1 = create_uuid();
	const id2 = create_uuid();
	const id3 = create_uuid();
	const id4 = create_uuid();

	beforeEach(() => {
		// Setup a real Zzz instance for testing
		zzz = monkeypatch_zzz_for_tests(new Zzz());

		// Create test items with intentional name collisions to test stable sorting
		items = [
			new Test_Cell(zzz, id3, 'Banana', 10, 30),
			new Test_Cell(zzz, id1, 'Apple', 5, 10),
			new Test_Cell(zzz, id2, 'Cherry', 15, 20),
			new Test_Cell(zzz, id4, 'Apple', 20, 40), // Same name as item with id1
		];

		sorters = [
			sort_by_text('name', 'Name', 'name'),
			sort_by_text('name_desc', 'Name (desc)', 'name', 'desc'),
			sort_by_numeric('value', 'Value', 'value'),
			sort_by_numeric('value_desc', 'Value (desc)', 'value', 'desc'),
		];
	});

	describe('constructor', () => {
		test('initializes with default values', () => {
			const sortable = new Sortable(
				() => items,
				() => sorters,
			);

			expect(sortable.items).toBe(items);
			expect(sortable.sorters).toBe(sorters);
			expect(sortable.active_key).toBe(sorters[0].key);
			expect(sortable.active_sorter).toBe(sorters[0]);
			expect(sortable.active_sort_fn).toBe(sorters[0].fn);
		});

		test('uses default key when provided', () => {
			const sortable = new Sortable(
				() => items,
				() => sorters,
				() => 'value',
			);

			expect(sortable.default_key).toBe('value');
			expect(sortable.active_key).toBe('value');
			expect(sortable.active_sorter).toBe(sorters[2]);
		});

		test('falls back to first sorter when default key is invalid', () => {
			const sortable = new Sortable(
				() => items,
				() => sorters,
				() => 'invalid_key',
			);

			expect(sortable.default_key).toBe('invalid_key');
			expect(sortable.active_key).toBe(sorters[0].key);
		});

		test('handles empty sorters array', () => {
			const sortable = new Sortable(
				() => items,
				() => [],
			);

			expect(sortable.active_key).toBe('');
			expect(sortable.active_sorter).toBeUndefined();
			expect(sortable.active_sort_fn).toBeUndefined();
		});
	});

	describe('update_active_key', () => {
		test('updates key when sorters change', () => {
			let current_sorters = $state([...sorters]);
			const sortable = new Sortable(
				() => items,
				() => current_sorters,
			);

			expect(sortable.active_key).toBe(sorters[0].key);

			// Change sorters to new array without the current active key
			current_sorters = [sorters[2], sorters[3]];

			// Since the effect has been removed, manually call update_active_key
			// Expect active key to change to value (the key of the first sorter in the new array)
			sortable.update_active_key();

			// Now the active key should match the first sorter in the new array
			expect(sortable.active_key).toBe('value');
		});

		test('preserves active key if still valid after sorters change', () => {
			let current_sorters = [...sorters];
			const sortable = new Sortable(
				() => items,
				() => current_sorters,
			);

			// Set active key to the second sorter
			sortable.active_key = sorters[1].key;

			// Change sorters but keep the active key
			current_sorters = [sorters[1], sorters[2]];
			sortable.update_active_key();

			expect(sortable.active_key).toBe(sorters[1].key);
		});
	});

	describe('sort_by_text', () => {
		test('sorts text values in ascending order', () => {
			const sortable = new Sortable(
				() => items,
				() => [sorters[0]],
			);
			const sorted = sortable.sorted_items;

			expect(sorted[0].name).toBe('Apple');
			expect(sorted[1].name).toBe('Apple');
			expect(sorted[2].name).toBe('Banana');
			expect(sorted[3].name).toBe('Cherry');

			// Verify that items with the same name are sorted by cid as fallback
			expect(sorted[0].cid).toBe(40); // First "Apple" has higher cid
			expect(sorted[1].cid).toBe(10); // Second "Apple" has lower cid
		});

		test('sorts text values in descending order', () => {
			const sortable = new Sortable(
				() => items,
				() => [sorters[1]],
			);
			const sorted = sortable.sorted_items;

			expect(sorted[0].name).toBe('Cherry');
			expect(sorted[1].name).toBe('Banana');
			expect(sorted[2].name).toBe('Apple');
			expect(sorted[3].name).toBe('Apple');

			// Verify that items with the same name are sorted by cid as fallback
			expect(sorted[2].cid).toBe(40); // First "Apple" has higher cid
			expect(sorted[3].cid).toBe(10); // Second "Apple" has lower cid
		});
	});

	describe('sort_by_numeric', () => {
		test('sorts numeric values in ascending order', () => {
			const sortable = new Sortable(
				() => items,
				() => [sorters[2]],
			);
			const sorted = sortable.sorted_items;

			expect(sorted[0].value).toBe(5);
			expect(sorted[1].value).toBe(10);
			expect(sorted[2].value).toBe(15);
			expect(sorted[3].value).toBe(20);
		});

		test('sorts numeric values in descending order', () => {
			const sortable = new Sortable(
				() => items,
				() => [sorters[3]],
			);
			const sorted = sortable.sorted_items;

			expect(sorted[0].value).toBe(20);
			expect(sorted[1].value).toBe(15);
			expect(sorted[2].value).toBe(10);
			expect(sorted[3].value).toBe(5);
		});

		test('maintains stable sort order with equal values using cid', () => {
			// Create items with equal values but different cids
			const equal_items = [
				new Test_Cell(zzz, create_uuid(), 'Item3', 10, 300),
				new Test_Cell(zzz, create_uuid(), 'Item1', 10, 100),
				new Test_Cell(zzz, create_uuid(), 'Item2', 10, 200),
			];

			const equal_sorter = sort_by_numeric<Test_Cell>('value', 'Value', 'value');
			const sortable = new Sortable(
				() => equal_items,
				() => [equal_sorter],
			);
			const sorted = sortable.sorted_items;

			// Items with equal values should be sorted by cid
			expect(sorted[0].cid).toBe(300);
			expect(sorted[1].cid).toBe(200);
			expect(sorted[2].cid).toBe(100);
		});
	});

	describe('reactivity', () => {
		test('updates sorted_items when source items change', () => {
			// Need a reactive reference to items that we can update
			let current_items = $state([...items]);
			const sortable = new Sortable(
				() => current_items,
				() => sorters,
			);

			// Start with 4 items
			expect(sortable.sorted_items.length).toBe(4);

			// Add a new item
			const new_item = new Test_Cell(zzz, create_uuid(), 'Dragonfruit', 25, 50);

			// Update the items array reference so the derived getter gets the new value
			current_items = [...current_items, new_item];

			// Now we should see 5 items
			expect(sortable.sorted_items.length).toBe(5);
			expect(sortable.sorted_items.some((item) => item.cid === 50)).toBe(true);
		});

		test('updates when active_key changes', () => {
			const sortable = new Sortable(
				() => items,
				() => sorters,
			);

			// Initially sorted by name (first sorter)
			expect(sortable.sorted_items[0].name).toBe('Apple');

			// Change to sort by value
			sortable.active_key = 'value';

			// Should now be sorted by value
			expect(sortable.sorted_items[0].value).toBe(5);
		});
	});
});
