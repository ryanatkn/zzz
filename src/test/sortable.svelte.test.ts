// @slop Claude Sonnet 3.7

// @vitest-environment jsdom

import {test, expect, describe, beforeEach} from 'vitest';
import {z} from 'zod';

import {Sortable, type Sorter, sort_by_text, sort_by_numeric} from '$lib/sortable.svelte.js';
import {Cell} from '$lib/cell.svelte.js';
import {Uuid_With_Default, type Uuid, Datetime_Now, create_uuid} from '$lib/zod_helpers.js';
import {Frontend} from '$lib/frontend.svelte.js';
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

	constructor(app: Frontend, id: Uuid, name: string, value: number, override_cid?: number) {
		super(Test_Cell_Schema, {
			app,
			json: {
				id,
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
	let app: Frontend;

	const id1 = create_uuid();
	const id2 = create_uuid();
	const id3 = create_uuid();
	const id4 = create_uuid();

	beforeEach(() => {
		// Setup a real Zzz instance for testing
		app = monkeypatch_zzz_for_tests(new Frontend());

		// Create test items with intentional name collisions to test stable sorting
		items = [
			new Test_Cell(app, id3, 'Banana', 10, 30),
			new Test_Cell(app, id1, 'Apple', 5, 10),
			new Test_Cell(app, id2, 'Cherry', 15, 20),
			new Test_Cell(app, id4, 'Apple', 20, 40), // Same name as item with id1
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

			const first_sorter = sorters[0];
			expect(first_sorter).toBeDefined();
			expect(sortable.items).toBe(items);
			expect(sortable.sorters).toBe(sorters);
			expect(sortable.active_key).toBe(first_sorter!.key);
			expect(sortable.active_sorter).toBe(first_sorter);
			expect(sortable.active_sort_fn).toBe(first_sorter!.fn);
		});

		test('uses default key when provided', () => {
			const sortable = new Sortable(
				() => items,
				() => sorters,
				() => 'value',
			);

			const sorter_at_2 = sorters[2];
			expect(sorter_at_2).toBeDefined();
			expect(sortable.default_key).toBe('value');
			expect(sortable.active_key).toBe('value');
			expect(sortable.active_sorter).toBe(sorter_at_2);
		});

		test('falls back to first sorter when default key is invalid', () => {
			const sortable = new Sortable(
				() => items,
				() => sorters,
				() => 'invalid_key',
			);

			const first_sorter = sorters[0];
			expect(first_sorter).toBeDefined();
			expect(sortable.default_key).toBe('invalid_key');
			expect(sortable.active_key).toBe(first_sorter!.key);
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

			const first_sorter = sorters[0];
			expect(first_sorter).toBeDefined();
			expect(sortable.active_key).toBe(first_sorter!.key);

			// Change sorters to new array without the current active key
			current_sorters = [sorters[2]!, sorters[3]!];

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

			const sorter_at_1 = sorters[1];
			const sorter_at_2 = sorters[2];
			expect(sorter_at_1).toBeDefined();
			expect(sorter_at_2).toBeDefined();

			// Set active key to the second sorter
			sortable.active_key = sorter_at_1!.key;

			// Change sorters but keep the active key
			current_sorters = [sorter_at_1!, sorter_at_2!];
			sortable.update_active_key();

			expect(sortable.active_key).toBe(sorter_at_1!.key);
		});
	});

	describe('sort_by_text', () => {
		test('sorts text values in ascending order', () => {
			const sorter_0 = sorters[0];
			expect(sorter_0).toBeDefined();
			const sortable = new Sortable(
				() => items,
				() => [sorter_0!],
			);
			const sorted = sortable.sorted_items;

			const item0 = sorted[0];
			const item1 = sorted[1];
			const item2 = sorted[2];
			const item3 = sorted[3];
			expect(item0).toBeDefined();
			expect(item1).toBeDefined();
			expect(item2).toBeDefined();
			expect(item3).toBeDefined();

			expect(item0!.name).toBe('Apple');
			expect(item1!.name).toBe('Apple');
			expect(item2!.name).toBe('Banana');
			expect(item3!.name).toBe('Cherry');

			// Verify that items with the same name are sorted by cid as fallback
			expect(item0!.cid).toBe(40); // First "Apple" has higher cid
			expect(item1!.cid).toBe(10); // Second "Apple" has lower cid
		});

		test('sorts text values in descending order', () => {
			const sorter_1 = sorters[1];
			expect(sorter_1).toBeDefined();
			const sortable = new Sortable(
				() => items,
				() => [sorter_1!],
			);
			const sorted = sortable.sorted_items;

			const item0 = sorted[0];
			const item1 = sorted[1];
			const item2 = sorted[2];
			const item3 = sorted[3];
			expect(item0).toBeDefined();
			expect(item1).toBeDefined();
			expect(item2).toBeDefined();
			expect(item3).toBeDefined();

			expect(item0!.name).toBe('Cherry');
			expect(item1!.name).toBe('Banana');
			expect(item2!.name).toBe('Apple');
			expect(item3!.name).toBe('Apple');

			// Verify that items with the same name are sorted by cid as fallback
			expect(item2!.cid).toBe(40); // First "Apple" has higher cid
			expect(item3!.cid).toBe(10); // Second "Apple" has lower cid
		});
	});

	describe('sort_by_numeric', () => {
		test('sorts numeric values in ascending order', () => {
			const sorter_2 = sorters[2];
			expect(sorter_2).toBeDefined();
			const sortable = new Sortable(
				() => items,
				() => [sorter_2!],
			);
			const sorted = sortable.sorted_items;

			const item0 = sorted[0];
			const item1 = sorted[1];
			const item2 = sorted[2];
			const item3 = sorted[3];
			expect(item0).toBeDefined();
			expect(item1).toBeDefined();
			expect(item2).toBeDefined();
			expect(item3).toBeDefined();

			expect(item0!.value).toBe(5);
			expect(item1!.value).toBe(10);
			expect(item2!.value).toBe(15);
			expect(item3!.value).toBe(20);
		});

		test('sorts numeric values in descending order', () => {
			const sorter_3 = sorters[3];
			expect(sorter_3).toBeDefined();
			const sortable = new Sortable(
				() => items,
				() => [sorter_3!],
			);
			const sorted = sortable.sorted_items;

			const item0 = sorted[0];
			const item1 = sorted[1];
			const item2 = sorted[2];
			const item3 = sorted[3];
			expect(item0).toBeDefined();
			expect(item1).toBeDefined();
			expect(item2).toBeDefined();
			expect(item3).toBeDefined();

			expect(item0!.value).toBe(20);
			expect(item1!.value).toBe(15);
			expect(item2!.value).toBe(10);
			expect(item3!.value).toBe(5);
		});

		test('maintains stable sort order with equal values using cid', () => {
			// Create items with equal values but different cids
			const equal_items = [
				new Test_Cell(app, create_uuid(), 'Item3', 10, 300),
				new Test_Cell(app, create_uuid(), 'Item1', 10, 100),
				new Test_Cell(app, create_uuid(), 'Item2', 10, 200),
			];

			const equal_sorter = sort_by_numeric<Test_Cell>('value', 'Value', 'value');
			const sortable = new Sortable(
				() => equal_items,
				() => [equal_sorter],
			);
			const sorted = sortable.sorted_items;

			const item0 = sorted[0];
			const item1 = sorted[1];
			const item2 = sorted[2];
			expect(item0).toBeDefined();
			expect(item1).toBeDefined();
			expect(item2).toBeDefined();

			// Items with equal values should be sorted by cid
			expect(item0!.cid).toBe(300);
			expect(item1!.cid).toBe(200);
			expect(item2!.cid).toBe(100);
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
			const new_item = new Test_Cell(app, create_uuid(), 'Dragonfruit', 25, 50);

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

			const first_item = sortable.sorted_items[0];
			expect(first_item).toBeDefined();

			// Initially sorted by name (first sorter)
			expect(first_item!.name).toBe('Apple');

			// Change to sort by value
			sortable.active_key = 'value';

			const first_item_after = sortable.sorted_items[0];
			expect(first_item_after).toBeDefined();

			// Should now be sorted by value
			expect(first_item_after!.value).toBe(5);
		});
	});
});
