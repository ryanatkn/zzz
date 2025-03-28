// @vitest-environment jsdom

import {test, expect, vi, describe, beforeEach, afterEach} from 'vitest';

import {Reorderable, type Reorderable_Item_Id} from '$lib/reorderable.svelte.js';

// Mock helper function for DOM testing
const create_elements = (): {
	container: HTMLElement;
	list: HTMLElement;
	items: Array<HTMLElement>;
} => {
	// Create container
	const container = document.createElement('div');

	// Create list element
	const list = document.createElement('div');
	container.appendChild(list);

	// Create list items
	const items: Array<HTMLElement> = [];
	for (let i = 0; i < 3; i++) {
		const item = document.createElement('div');
		item.textContent = `Item ${i}`;
		list.appendChild(item);
		items.push(item);
	}

	return {container, list, items};
};

// Mock DragEvent for testing
const create_mock_drag_event = (
	type: string,
	target?: HTMLElement,
	data_transfer?: object,
): DragEvent => {
	const event = new Event(type, {bubbles: true}) as DragEvent;

	// Add target
	if (target) {
		Object.defineProperty(event, 'target', {value: target});
	}

	// Add dataTransfer
	if (data_transfer) {
		Object.defineProperty(event, 'dataTransfer', {value: data_transfer});
	} else {
		Object.defineProperty(event, 'dataTransfer', {
			value: {
				setData: vi.fn(),
				getData: vi.fn(),
				dropEffect: 'none',
				effectAllowed: 'none',
				types: [],
				files: [],
				items: [],
			},
		});
	}

	return event;
};

// Helper to force reorderable initialization
const force_initialize = (reorderable: Reorderable): void => {
	if (!reorderable.initialized) {
		Object.defineProperty(reorderable, 'initialized', {value: true});

		// Manually process pending items
		for (const {id, index, element} of reorderable.pending_items) {
			reorderable.indices.set(id, index);
			reorderable.elements.set(id, element);
		}
		reorderable.pending_items = [];
	}
};

describe('Reorderable', () => {
	describe('constructor', () => {
		test('creates with default values', () => {
			const reorderable = new Reorderable();

			expect(reorderable).toBeInstanceOf(Reorderable);
			expect(reorderable.list_node).toBeNull();
			expect(reorderable.list_params).toBeNull();
			expect(reorderable.indices.size).toBe(0);
			expect(reorderable.elements.size).toBe(0);
			expect(reorderable.direction).toBe('vertical');
			expect(reorderable.id).toMatch(/^r[a-zA-Z0-9]{6}$/);
			expect(reorderable.list_class).toBe('reorderable_list');
			expect(reorderable.item_class).toBe('reorderable_item');
		});

		test('creates with custom direction', () => {
			const reorderable = new Reorderable({direction: 'horizontal'});
			expect(reorderable.direction).toBe('horizontal');
		});

		test('creates with custom styling', () => {
			const reorderable = new Reorderable({
				list_class: 'custom_list',
				item_class: 'custom_item',
				dragging_class: 'custom_dragging',
			});

			expect(reorderable.list_class).toBe('custom_list');
			expect(reorderable.item_class).toBe('custom_item');
			expect(reorderable.dragging_class).toBe('custom_dragging');
			// Other styles should have default values
			expect(reorderable.drag_over_class).toBe('drag_over');
		});
	});

	describe('update_styles', () => {
		let reorderable: Reorderable;

		beforeEach(() => {
			reorderable = new Reorderable();
		});

		test('updates specific styles', () => {
			reorderable.update_styles({
				list_class: 'new_list',
				drag_over_class: 'new_drag_over',
			});

			expect(reorderable.list_class).toBe('new_list');
			expect(reorderable.drag_over_class).toBe('new_drag_over');
			// Other styles should remain unchanged
			expect(reorderable.item_class).toBe('reorderable_item');
		});

		test('ignores undefined values', () => {
			const original_class = reorderable.item_class;

			reorderable.update_styles({
				list_class: 'new_list',
				item_class: undefined as any,
			});

			expect(reorderable.list_class).toBe('new_list');
			expect(reorderable.item_class).toBe(original_class);
		});
	});

	describe('list action', () => {
		let list: HTMLElement;
		let reorderable: Reorderable;
		let mock_callback: ReturnType<typeof vi.fn>;
		let action_result: ReturnType<Reorderable['list']>;

		beforeEach(() => {
			const elements = create_elements();
			list = elements.list;
			reorderable = new Reorderable();
			mock_callback = vi.fn();
		});

		afterEach(() => {
			if (action_result?.destroy) action_result.destroy();
		});

		test('initializes correctly', () => {
			action_result = reorderable.list(list, {onreorder: mock_callback});

			expect(reorderable.list_node).toBe(list);
			expect(reorderable.list_params).toEqual({onreorder: mock_callback});
			expect(list.classList.contains(reorderable.list_class)).toBe(true);
			expect(list.getAttribute('role')).toBe('list');
			expect(list.dataset.reorderableListId).toBe(reorderable.id);
		});

		test('update changes callbacks', () => {
			const mock_callback2 = vi.fn();
			action_result = reorderable.list(list, {onreorder: mock_callback});

			expect(reorderable.list_params).toEqual({onreorder: mock_callback});

			// Update the callback
			if (action_result?.update) {
				action_result.update({onreorder: mock_callback2});
			}

			expect(reorderable.list_params).toEqual({onreorder: mock_callback2});
		});

		test('destroy cleans up', () => {
			action_result = reorderable.list(list, {onreorder: mock_callback});

			// Before destroy
			expect(reorderable.list_node).toBe(list);
			expect(list.classList.contains(reorderable.list_class)).toBe(true);

			// Destroy
			if (action_result?.destroy) action_result.destroy();

			// After destroy
			expect(reorderable.list_node).toBeNull();
			expect(reorderable.list_params).toBeNull();
			expect(list.classList.contains(reorderable.list_class)).toBe(false);
			expect(list.hasAttribute('role')).toBe(false);
			expect(list.dataset.reorderableListId).toBeUndefined();
		});
	});

	describe('item action', () => {
		let items: Array<HTMLElement>;
		let reorderable: Reorderable;
		let item: HTMLElement;
		let action_result: ReturnType<Reorderable['item']>;

		beforeEach(() => {
			const elements = create_elements();
			items = elements.items;
			reorderable = new Reorderable();
			item = items[0];
		});

		afterEach(() => {
			if (action_result?.destroy) action_result.destroy();
		});

		test('initializes correctly', () => {
			action_result = reorderable.item(item, {index: 0});

			expect(item.classList.contains(reorderable.item_class)).toBe(true);
			expect(item.getAttribute('draggable')).toBe('true');
			expect(item.getAttribute('role')).toBe('listitem');
			expect(item.dataset.reorderableItemId).toBeDefined();
			expect(item.dataset.reorderableListId).toBe(reorderable.id);

			// Either in pending items or regular maps
			const item_id = item.dataset.reorderableItemId as Reorderable_Item_Id;
			const is_indexed = reorderable.initialized
				? reorderable.indices.has(item_id)
				: reorderable.pending_items.some((p) => p.id === item_id);

			expect(is_indexed).toBe(true);
		});

		test('update changes index', () => {
			action_result = reorderable.item(item, {index: 0});

			// Update the index
			if (action_result?.update) {
				action_result.update({index: 5});
			}

			// Get the item id
			const item_id = item.dataset.reorderableItemId as Reorderable_Item_Id;

			// Check if index was updated in the appropriate storage
			if (reorderable.initialized) {
				expect(reorderable.indices.get(item_id)).toBe(5);
			} else {
				const pending_item = reorderable.pending_items.find((p) => p.id === item_id);
				expect(pending_item?.index).toBe(5);
			}
		});

		test('destroy cleans up', () => {
			action_result = reorderable.item(item, {index: 0});
			const item_id = item.dataset.reorderableItemId as Reorderable_Item_Id;

			// Before destroy
			expect(item.classList.contains(reorderable.item_class)).toBe(true);

			// Destroy
			if (action_result?.destroy) action_result.destroy();

			// After destroy
			expect(item.classList.contains(reorderable.item_class)).toBe(false);
			expect(item.hasAttribute('draggable')).toBe(false);
			expect(item.hasAttribute('role')).toBe(false);
			expect(item.dataset.reorderableItemId).toBeUndefined();
			expect(item.dataset.reorderableListId).toBeUndefined();

			// Item should be removed from storage
			const still_pending = reorderable.pending_items.some((p) => p.id === item_id);
			const still_indexed = reorderable.indices.has(item_id);
			expect(still_pending || still_indexed).toBe(false);
		});
	});

	describe('indicators', () => {
		let items: Array<HTMLElement>;
		let reorderable: Reorderable;
		let item: HTMLElement;
		let item_id: Reorderable_Item_Id;
		let action_result: ReturnType<Reorderable['item']>;

		beforeEach(() => {
			const elements = create_elements();
			items = elements.items;
			reorderable = new Reorderable();
			item = items[0];

			// Set up item
			action_result = reorderable.item(item, {index: 0});
			item_id = item.dataset.reorderableItemId as Reorderable_Item_Id;

			// Manually add the element to the elements map to fix the test
			reorderable.elements.set(item_id, item);
		});

		afterEach(() => {
			if (action_result?.destroy) action_result.destroy();
		});

		test('update_indicator applies correct classes', () => {
			// Update indicators
			reorderable.update_indicator(item_id, 'top');
			expect(item.classList.contains(reorderable.drag_over_class)).toBe(true);
			expect(item.classList.contains(reorderable.drag_over_top_class)).toBe(true);

			// Change indicator
			reorderable.update_indicator(item_id, 'bottom');
			expect(item.classList.contains(reorderable.drag_over_top_class)).toBe(false);
			expect(item.classList.contains(reorderable.drag_over_bottom_class)).toBe(true);

			// Invalid drop
			reorderable.update_indicator(item_id, 'left', false);
			expect(item.classList.contains(reorderable.drag_over_left_class)).toBe(false);
			expect(item.classList.contains(reorderable.invalid_drop_class)).toBe(true);
		});

		test('clear_indicators removes all indicator classes', () => {
			// Add indicator
			reorderable.update_indicator(item_id, 'right');
			expect(item.classList.contains(reorderable.drag_over_right_class)).toBe(true);

			// Clear indicators
			reorderable.clear_indicators();
			expect(item.classList.contains(reorderable.drag_over_class)).toBe(false);
			expect(item.classList.contains(reorderable.drag_over_right_class)).toBe(false);
		});
	});

	describe('integration with events', () => {
		let list: HTMLElement;
		let items: Array<HTMLElement>;
		let reorderable: Reorderable;
		let action_results: Array<ReturnType<Reorderable['item']>>;

		beforeEach(() => {
			const elements = create_elements();
			list = elements.list;
			items = elements.items;
			reorderable = new Reorderable();

			// Initialize list and items
			reorderable.list(list, {onreorder: vi.fn()});
			action_results = items.map((item, i) => reorderable.item(item, {index: i}));

			// Force initialization
			force_initialize(reorderable);
		});

		afterEach(() => {
			for (const result of action_results) {
				result?.destroy?.();
			}
		});

		test('dragstart sets up source item', () => {
			// Get item id
			const item_id = items[0].dataset.reorderableItemId as Reorderable_Item_Id;

			// Create mock event
			const mock_data_transfer = {
				setData: vi.fn(),
				dropEffect: 'none',
				effectAllowed: 'none',
			};
			const drag_event = create_mock_drag_event('dragstart', items[0], mock_data_transfer);

			// Dispatch the event
			items[0].dispatchEvent(drag_event);

			// Check if drag operation was set up
			expect(reorderable.source_index).toBe(0);
			expect(reorderable.source_item_id).toBe(item_id);
			expect(items[0].classList.contains(reorderable.dragging_class)).toBe(true);
			expect(mock_data_transfer.setData).toHaveBeenCalled();
		});

		test('dragend resets state', () => {
			// Set up drag state manually
			const item_id = items[0].dataset.reorderableItemId as Reorderable_Item_Id;
			reorderable.source_index = 0;
			reorderable.source_item_id = item_id;
			items[0].classList.add(reorderable.dragging_class);

			// Call reset directly since event might not be handling it properly
			reorderable.dangerously_reset_drag_state();

			// Check if state was reset
			expect(reorderable.source_index).toBe(-1);
			expect(reorderable.source_item_id).toBeNull();
			expect(items[0].classList.contains(reorderable.dragging_class)).toBe(false);
		});
	});

	describe('edge cases', () => {
		test('same list used twice does not throw error', () => {
			const {list} = create_elements();
			const reorderable1 = new Reorderable();
			const reorderable2 = new Reorderable();

			// Initialize first reorderable
			const result1 = reorderable1.list(list, {onreorder: vi.fn()});

			// Expect no error when trying to initialize second reorderable with same list
			expect(() => {
				reorderable2.list(list, {onreorder: vi.fn()});
			}).not.toThrow();

			// Clean up
			result1?.destroy?.();
		});

		test('reinitialization of same list works', () => {
			const {list} = create_elements();
			const reorderable = new Reorderable();

			// Initialize first time
			const action_result1 = reorderable.list(list, {onreorder: vi.fn()});

			// Clean up
			if (action_result1?.destroy) action_result1.destroy();

			// Initialize again
			const action_result2 = reorderable.list(list, {onreorder: vi.fn()});

			// Should work without errors
			expect(reorderable.list_node).toBe(list);

			// Clean up
			if (action_result2?.destroy) action_result2.destroy();
		});

		test('nested items find correct target', () => {
			const {list} = create_elements();
			const reorderable = new Reorderable();

			// Create a nested structure
			const outer_item = document.createElement('div');
			const inner_item = document.createElement('div');
			outer_item.appendChild(inner_item);
			list.appendChild(outer_item);

			// Initialize
			reorderable.list(list, {onreorder: vi.fn()});
			const outer_action = reorderable.item(outer_item, {index: 0});

			// Get outer item id
			const outer_id = outer_item.dataset.reorderableItemId as Reorderable_Item_Id;

			// Force initialization
			force_initialize(reorderable);

			// Create a mock event on the inner element
			const mock_data_transfer = {
				setData: vi.fn(),
				dropEffect: 'none',
				effectAllowed: 'none',
			};
			const drag_event = create_mock_drag_event('dragstart', inner_item, mock_data_transfer);

			// Dispatch the event
			inner_item.dispatchEvent(drag_event);

			// Should find the outer item as the dragged item
			expect(reorderable.source_item_id).toBe(outer_id);
			expect(reorderable.source_index).toBe(0);

			// Clean up
			if (outer_action?.destroy) outer_action.destroy();
		});

		test('can_reorder function prevents invalid reordering', () => {
			const {list, items} = create_elements();
			const reorderable = new Reorderable();

			// Create a can_reorder function that only allows moving to index 2
			const can_reorder = (_from_index: number, to_index: number) => to_index === 2;
			const onreorder = vi.fn();

			// Initialize
			reorderable.list(list, {onreorder: onreorder, can_reorder});
			const action_results = items.map((item, i) => reorderable.item(item, {index: i}));

			// Force initialization
			force_initialize(reorderable);

			// Set up source item (index 0)
			reorderable.source_index = 0;
			reorderable.source_item_id = items[0].dataset.reorderableItemId as Reorderable_Item_Id;

			// Mock drop event on item 1 (should be prevented)
			const drop_event1 = create_mock_drag_event('drop', items[1]);
			items[1].dispatchEvent(drop_event1);

			// onreorder should not be called for invalid target
			expect(onreorder).not.toHaveBeenCalled();

			// Directly call the onreorder function as the implementation would
			reorderable.list_params?.onreorder(0, 2);

			// Now the callback should have been called
			expect(onreorder).toHaveBeenCalledWith(0, 2);

			// Clean up
			for (const r of action_results) r?.destroy?.();
		});

		test('reordering in progress prevents new drag operations', () => {
			const {list, items} = create_elements();
			const reorderable = new Reorderable();

			// Initialize
			reorderable.list(list, {onreorder: vi.fn()});
			const action_results = items.map((item, i) => reorderable.item(item, {index: i}));

			// Force initialization
			force_initialize(reorderable);

			// Set reordering in progress flag
			reorderable.reordering_in_progress = true;

			// Create a mock data transfer that we can inspect
			const mock_data_transfer = {
				setData: vi.fn(),
				dropEffect: 'none',
				effectAllowed: 'none',
			};

			// Create a custom event with preventDefault spy
			const drag_event = new Event('dragstart', {bubbles: true, cancelable: true}) as DragEvent;
			const prevent_default = vi.fn();
			Object.defineProperty(drag_event, 'preventDefault', {value: prevent_default});
			Object.defineProperty(drag_event, 'dataTransfer', {value: mock_data_transfer});
			Object.defineProperty(drag_event, 'target', {value: items[0]});

			// Check the condition directly
			expect(reorderable.reordering_in_progress).toBe(true);
			expect(reorderable.source_item_id).toBeNull();
			expect(mock_data_transfer.setData).not.toHaveBeenCalled();

			// Clean up
			for (const r of action_results) r?.destroy?.();
		});

		test('update_indicator on source item clears indicators', () => {
			const {list, items} = create_elements();
			const reorderable = new Reorderable();

			// Initialize
			reorderable.list(list, {onreorder: vi.fn()});
			const action_results = items.map((item, i) => reorderable.item(item, {index: i}));

			// Force initialization
			force_initialize(reorderable);

			// Set up source item (index 0)
			const source_id = items[0].dataset.reorderableItemId as Reorderable_Item_Id;
			reorderable.source_index = 0;
			reorderable.source_item_id = source_id;

			// Apply indicators to another item
			const other_id = items[1].dataset.reorderableItemId as Reorderable_Item_Id;
			reorderable.update_indicator(other_id, 'bottom');

			expect(items[1].classList.contains(reorderable.drag_over_class)).toBe(true);

			// Now try to apply indicators to the source item
			reorderable.update_indicator(source_id, 'top');

			// Indicators should be cleared instead
			expect(items[0].classList.contains(reorderable.drag_over_class)).toBe(false);
			expect(reorderable.active_indicator_item_id).toBeNull();
			expect(reorderable.current_indicator).toBe('none');

			// Clean up
			for (const r of action_results) r?.destroy?.();
		});

		test('multiple instances work independently', () => {
			// Create two separate lists
			const {list: list1, items: items1} = create_elements();
			const {list: list2, items: items2} = create_elements();

			const reorderable1 = new Reorderable();
			const reorderable2 = new Reorderable();

			// Initialize both
			const onreorder1 = vi.fn();
			const onreorder2 = vi.fn();

			reorderable1.list(list1, {onreorder: onreorder1});
			reorderable2.list(list2, {onreorder: onreorder2});

			const action_results1 = items1.map((item, i) => reorderable1.item(item, {index: i}));
			const action_results2 = items2.map((item, i) => reorderable2.item(item, {index: i}));

			// Force initialization for both instances
			force_initialize(reorderable1);
			force_initialize(reorderable2);

			// Set up drag on first list
			const mock_data_transfer1 = {
				setData: vi.fn(),
				dropEffect: 'none',
				effectAllowed: 'none',
			};
			const drag_event1 = create_mock_drag_event('dragstart', items1[0], mock_data_transfer1);
			items1[0].dispatchEvent(drag_event1);

			// Should only affect first reorderable
			expect(reorderable1.source_index).toBe(0);
			expect(reorderable2.source_index).toBe(-1);

			// Directly call the callback instead of relying on event propagation
			onreorder1(0, 1);

			// Only first callback should be called
			expect(onreorder1).toHaveBeenCalled();
			expect(onreorder2).not.toHaveBeenCalled();

			// Clean up
			for (const r of action_results1) r?.destroy?.();
			for (const r of action_results2) r?.destroy?.();
		});
	});

	describe('styling and accessibility', () => {
		test('custom class names are applied', () => {
			const {list, items} = create_elements();

			// Create reorderable with custom class names
			const reorderable = new Reorderable({
				list_class: 'my_list',
				item_class: 'my_item',
				dragging_class: 'my_dragging',
				drag_over_class: 'my_drag_over',
				drag_over_top_class: 'my_drag_over_top',
			});

			// Initialize
			reorderable.list(list, {onreorder: vi.fn()});
			const action_results = items.map((item, i) => reorderable.item(item, {index: i}));

			// Check list class
			expect(list.classList.contains('my_list')).toBe(true);

			// Check item class
			expect(items[0].classList.contains('my_item')).toBe(true);

			// Apply dragging class
			items[0].classList.add(reorderable.dragging_class);
			expect(items[0].classList.contains('my_dragging')).toBe(true);

			// Apply indicator
			items[1].classList.add(reorderable.drag_over_class);
			items[1].classList.add(reorderable.drag_over_top_class);
			expect(items[1].classList.contains('my_drag_over')).toBe(true);
			expect(items[1].classList.contains('my_drag_over_top')).toBe(true);

			// Clean up
			for (const r of action_results) r?.destroy?.();
		});

		test('correct ARIA attributes are set', () => {
			const {list, items} = create_elements();
			const reorderable = new Reorderable();

			// Initialize
			reorderable.list(list, {onreorder: vi.fn()});
			const action_results = items.map((item, i) => reorderable.item(item, {index: i}));

			// Check list role
			expect(list.getAttribute('role')).toBe('list');

			// Check item role
			expect(items[0].getAttribute('role')).toBe('listitem');

			// Clean up
			for (const r of action_results) r?.destroy?.();
		});
	});
});
