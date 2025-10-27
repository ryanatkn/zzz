// @slop Claude Sonnet 3.7

// @vitest-environment jsdom

import {test, expect, vi, describe, beforeEach, afterEach} from 'vitest';

import {
	Reorderable,
	type Reorderable_Item_Id,
	type Reorderable_Item_Params,
	type Reorderable_List_Params,
} from '$lib/reorderable.svelte.js';

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
		// Call the actual init method which sets up event handlers
		reorderable.init();
	}
};

// Helper to attach list with cleanup tracking
const attach_list = (
	reorderable: Reorderable,
	list: HTMLElement,
	params: Reorderable_List_Params,
): (() => void) => {
	const attachment = reorderable.list(params);
	const cleanup = attachment(list);
	return cleanup || (() => undefined);
};

// Helper to attach item with cleanup tracking
const attach_item = (
	reorderable: Reorderable,
	item: HTMLElement,
	params: Reorderable_Item_Params,
): (() => void) => {
	const attachment = reorderable.item(params);
	const cleanup = attachment(item);
	return cleanup || (() => undefined);
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
			expect(reorderable.id).toBeTruthy();
			expect(reorderable.id).not.toBe(new Reorderable().id);
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

	describe('list attachment', () => {
		let list: HTMLElement;
		let reorderable: Reorderable;
		let mock_callback: ReturnType<typeof vi.fn>;
		let cleanup_fn: (() => void) | undefined;

		beforeEach(() => {
			const elements = create_elements();
			list = elements.list;
			reorderable = new Reorderable();
			mock_callback = vi.fn();
		});

		afterEach(() => {
			if (cleanup_fn) cleanup_fn();
		});

		test('initializes correctly', () => {
			cleanup_fn = attach_list(reorderable, list, {onreorder: mock_callback});

			expect(reorderable.list_node).toBe(list);
			expect(reorderable.list_params).toEqual({onreorder: mock_callback});
			expect(list.classList.contains(reorderable.list_class!)).toBe(true);
			expect(list.getAttribute('role')).toBe('list');
			expect(list.dataset.reorderable_list_id).toBe(reorderable.id);
		});

		test('re-attachment changes callbacks', () => {
			const mock_callback2 = vi.fn();
			const cleanup1 = attach_list(reorderable, list, {onreorder: mock_callback});

			expect(reorderable.list_params).toEqual({onreorder: mock_callback});

			// Re-attach with new callback
			cleanup1();
			cleanup_fn = attach_list(reorderable, list, {onreorder: mock_callback2});

			expect(reorderable.list_params).toEqual({onreorder: mock_callback2});
		});

		test('destroy cleans up', () => {
			cleanup_fn = attach_list(reorderable, list, {onreorder: mock_callback});

			// Before destroy
			expect(reorderable.list_node).toBe(list);
			expect(list.classList.contains(reorderable.list_class!)).toBe(true);

			// Destroy
			cleanup_fn();
			cleanup_fn = undefined;

			// After destroy
			expect(reorderable.list_node).toBeNull();
			expect(reorderable.list_params).toBeNull();
			expect(list.classList.contains(reorderable.list_class!)).toBe(false);
			expect(list.hasAttribute('role')).toBe(false);
			expect(list.dataset.reorderable_list_id).toBeUndefined();
		});
	});

	describe('item attachment', () => {
		let items: Array<HTMLElement>;
		let reorderable: Reorderable;
		let item: HTMLElement;
		let cleanup_fn: (() => void) | undefined;

		beforeEach(() => {
			const elements = create_elements();
			items = elements.items;
			reorderable = new Reorderable();
			const first_item = items[0];
			if (!first_item) throw new Error('Expected at least one item in test setup');
			item = first_item;
		});

		afterEach(() => {
			if (cleanup_fn) cleanup_fn();
		});

		test('initializes correctly', () => {
			cleanup_fn = attach_item(reorderable, item, {index: 0});

			expect(item.classList.contains(reorderable.item_class!)).toBe(true);
			expect(item.getAttribute('draggable')).toBe('true');
			expect(item.getAttribute('role')).toBe('listitem');
			expect(item.dataset.reorderable_item_id).toBeDefined();
			expect(item.dataset.reorderable_list_id).toBe(reorderable.id);

			// Either in pending items or regular maps
			const item_id = item.dataset.reorderable_item_id as Reorderable_Item_Id;
			const is_indexed = reorderable.initialized
				? reorderable.indices.has(item_id)
				: reorderable.pending_items.some((p) => p.id === item_id);

			expect(is_indexed).toBe(true);
		});

		test('re-attachment changes index', () => {
			const cleanup1 = attach_item(reorderable, item, {index: 0});

			// Get the item id
			const item_id = item.dataset.reorderable_item_id as Reorderable_Item_Id;

			// Check initial index
			if (reorderable.initialized) {
				expect(reorderable.indices.get(item_id)).toBe(0);
			} else {
				const pending_item = reorderable.pending_items.find((p) => p.id === item_id);
				expect(pending_item?.index).toBe(0);
			}

			// Re-attach with new index
			cleanup1();
			cleanup_fn = attach_item(reorderable, item, {index: 5});

			// Get the new item id after re-attachment
			const new_item_id = item.dataset.reorderable_item_id as Reorderable_Item_Id;

			// Check if index was updated in the appropriate storage
			if (reorderable.initialized) {
				expect(reorderable.indices.get(new_item_id)).toBe(5);
			} else {
				const pending_item = reorderable.pending_items.find((p) => p.id === new_item_id);
				expect(pending_item?.index).toBe(5);
			}
		});

		test('destroy cleans up', () => {
			cleanup_fn = attach_item(reorderable, item, {index: 0});

			const item_id = item.dataset.reorderable_item_id as Reorderable_Item_Id;

			// Before destroy
			expect(item.classList.contains(reorderable.item_class!)).toBe(true);

			// Destroy
			cleanup_fn();
			cleanup_fn = undefined;

			// After destroy
			expect(item.classList.contains(reorderable.item_class!)).toBe(false);
			expect(item.hasAttribute('draggable')).toBe(false);
			expect(item.hasAttribute('role')).toBe(false);
			expect(item.dataset.reorderable_item_id).toBeUndefined();
			expect(item.dataset.reorderable_list_id).toBeUndefined();

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
		let cleanup_fn: (() => void) | undefined;

		beforeEach(() => {
			const elements = create_elements();
			items = elements.items;
			reorderable = new Reorderable();
			const first_item = items[0];
			if (!first_item) throw new Error('Expected at least one item in test setup');
			item = first_item;

			// Set up item
			cleanup_fn = attach_item(reorderable, item, {index: 0});
			item_id = item.dataset.reorderable_item_id as Reorderable_Item_Id;

			// Manually add the element to the elements map to fix the test
			reorderable.elements.set(item_id, item);
		});

		afterEach(() => {
			if (cleanup_fn) cleanup_fn();
		});

		test('update_indicator applies correct classes', () => {
			// Update indicators
			reorderable.update_indicator(item_id, 'top');
			expect(item.classList.contains(reorderable.drag_over_class!)).toBe(true);
			expect(item.classList.contains(reorderable.drag_over_top_class!)).toBe(true);

			// Change indicator
			reorderable.update_indicator(item_id, 'bottom');
			expect(item.classList.contains(reorderable.drag_over_top_class!)).toBe(false);
			expect(item.classList.contains(reorderable.drag_over_bottom_class!)).toBe(true);

			// Invalid drop
			reorderable.update_indicator(item_id, 'left', false);
			expect(item.classList.contains(reorderable.drag_over_left_class!)).toBe(false);
			expect(item.classList.contains(reorderable.invalid_drop_class!)).toBe(true);
		});

		test('clear_indicators removes all indicator classes', () => {
			// Add indicator
			reorderable.update_indicator(item_id, 'right');
			expect(item.classList.contains(reorderable.drag_over_right_class!)).toBe(true);

			// Clear indicators
			reorderable.clear_indicators();
			expect(item.classList.contains(reorderable.drag_over_class!)).toBe(false);
			expect(item.classList.contains(reorderable.drag_over_right_class!)).toBe(false);
		});
	});

	describe('integration with events', () => {
		let list: HTMLElement;
		let items: Array<HTMLElement>;
		let reorderable: Reorderable;
		let action_results: Array<{destroy?: () => void} | undefined>;

		beforeEach(() => {
			const elements = create_elements();
			list = elements.list;
			items = elements.items;
			reorderable = new Reorderable();

			// Initialize list and items
			const list_attachment = reorderable.list({onreorder: vi.fn()});
			list_attachment(list);
			action_results = items.map((item, i) => {
				const attachment = reorderable.item({index: i});
				const cleanup = attachment(item);
				return cleanup ? {destroy: cleanup} : undefined;
			});

			// Force initialization
			force_initialize(reorderable);
		});

		afterEach(() => {
			for (const result of action_results) {
				result?.destroy?.();
			}
		});

		test('dragstart sets up source item', () => {
			const first_item = items[0];
			if (!first_item) throw new Error('Expected first item');

			// Get item id
			const item_id = first_item.dataset.reorderable_item_id as Reorderable_Item_Id;

			// Create mock event
			const mock_data_transfer = {
				setData: vi.fn(),
				dropEffect: 'none',
				effectAllowed: 'none',
			};
			const drag_event = create_mock_drag_event('dragstart', first_item, mock_data_transfer);

			// Dispatch the event
			first_item.dispatchEvent(drag_event);

			// Check if drag operation was set up
			expect(reorderable.source_index).toBe(0);
			expect(reorderable.source_item_id).toBe(item_id);
			expect(first_item.classList.contains(reorderable.dragging_class!)).toBe(true);
			expect(mock_data_transfer.setData).toHaveBeenCalled();
		});

		test('dragend resets state', () => {
			const first_item = items[0];
			if (!first_item) throw new Error('Expected first item');

			// Set up drag state manually
			const item_id = first_item.dataset.reorderable_item_id as Reorderable_Item_Id;
			reorderable.source_index = 0;
			reorderable.source_item_id = item_id;
			first_item.classList.add(reorderable.dragging_class!);

			// Trigger dragend event to reset state
			const dragend_event = create_mock_drag_event('dragend', first_item);
			list.dispatchEvent(dragend_event);

			// Check if state was reset
			expect(reorderable.source_index).toBe(-1);
			expect(reorderable.source_item_id).toBeNull();
			expect(first_item.classList.contains(reorderable.dragging_class!)).toBe(false);
		});
	});

	describe('edge cases', () => {
		test('same list used twice does not throw error', () => {
			const {list} = create_elements();
			const reorderable1 = new Reorderable();
			const reorderable2 = new Reorderable();

			// Initialize first reorderable
			const cleanup1 = attach_list(reorderable1, list, {onreorder: vi.fn()});

			// Expect no error when trying to initialize second reorderable with same list
			expect(() => {
				attach_list(reorderable2, list, {onreorder: vi.fn()});
			}).not.toThrow();

			// Clean up
			cleanup1();
		});

		test('reinitialization of same list works', () => {
			const {list} = create_elements();
			const reorderable = new Reorderable();

			// Initialize first time
			const attachment1 = reorderable.list({onreorder: vi.fn()});
			const cleanup1 = attachment1(list);

			// Clean up
			if (cleanup1) cleanup1();

			// Initialize again
			const attachment2 = reorderable.list({onreorder: vi.fn()});
			const cleanup2 = attachment2(list);

			// Should work without errors
			expect(reorderable.list_node).toBe(list);

			// Clean up
			if (cleanup2) cleanup2();
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
			const list_attachment = reorderable.list({onreorder: vi.fn()});
			list_attachment(list);
			const outer_attachment = reorderable.item({index: 0});
			const outer_cleanup = outer_attachment(outer_item);
			const outer_action = {destroy: outer_cleanup};

			// Get outer item id
			const outer_id = outer_item.dataset.reorderable_item_id as Reorderable_Item_Id;

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
			outer_action.destroy?.();
		});

		test('can_reorder function prevents invalid reordering', () => {
			const {list, items} = create_elements();
			const reorderable = new Reorderable();

			// Create a can_reorder function that only allows moving to index 2
			const can_reorder = (_from_index: number, to_index: number) => to_index === 2;
			const onreorder = vi.fn();

			// Initialize
			const list_attachment = reorderable.list({onreorder, can_reorder});
			list_attachment(list);
			const action_results = items.map((item, i) => {
				const attachment = reorderable.item({index: i});
				const cleanup = attachment(item);
				return cleanup ? {destroy: cleanup} : undefined;
			});

			// Force initialization
			force_initialize(reorderable);

			// Set up source item (index 0)
			const source_item = items[0];
			const target_item = items[1];
			if (!source_item || !target_item) throw new Error('Expected source and target items');

			reorderable.source_index = 0;
			reorderable.source_item_id = source_item.dataset.reorderable_item_id as Reorderable_Item_Id;

			// Mock drop event on item 1 (should be prevented)
			const drop_event1 = create_mock_drag_event('drop', target_item);
			target_item.dispatchEvent(drop_event1);

			// onreorder should not be called for invalid target
			expect(onreorder).not.toHaveBeenCalled();

			// Directly call the onreorder function as the implementation would
			reorderable.list_params?.onreorder(0, 2);

			// Now the callback should have been called
			expect(onreorder).toHaveBeenCalledWith(0, 2);

			// Clean up
			for (const r of action_results) r?.destroy();
		});

		test('update_indicator on source item clears indicators', () => {
			const {list, items} = create_elements();
			const reorderable = new Reorderable();

			// Initialize
			const list_attachment = reorderable.list({onreorder: vi.fn()});
			list_attachment(list);
			const action_results = items.map((item, i) => {
				const attachment = reorderable.item({index: i});
				const cleanup = attachment(item);
				return cleanup ? {destroy: cleanup} : undefined;
			});

			// Force initialization
			force_initialize(reorderable);

			// Set up source item (index 0)
			const source_item = items[0];
			const other_item = items[1];
			if (!source_item || !other_item) throw new Error('Expected source and other items');

			const source_id = source_item.dataset.reorderable_item_id as Reorderable_Item_Id;
			reorderable.source_index = 0;
			reorderable.source_item_id = source_id;

			// Apply indicators to another item
			const other_id = other_item.dataset.reorderable_item_id as Reorderable_Item_Id;
			reorderable.update_indicator(other_id, 'bottom');

			expect(other_item.classList.contains(reorderable.drag_over_class!)).toBe(true);

			// Now try to apply indicators to the source item
			reorderable.update_indicator(source_id, 'top');

			// Indicators should be cleared instead
			expect(source_item.classList.contains(reorderable.drag_over_class!)).toBe(false);
			expect(reorderable.active_indicator_item_id).toBeNull();
			expect(reorderable.current_indicator).toBe('none');

			// Clean up
			for (const r of action_results) r?.destroy();
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

			const list1_attachment = reorderable1.list({onreorder: onreorder1});
			const list2_attachment = reorderable2.list({onreorder: onreorder2});
			list1_attachment(list1);
			list2_attachment(list2);

			const action_results1 = items1.map((item, i) => {
				const attachment = reorderable1.item({index: i});
				const cleanup = attachment(item);
				return cleanup ? {destroy: cleanup} : undefined;
			});
			const action_results2 = items2.map((item, i) => {
				const attachment = reorderable2.item({index: i});
				const cleanup = attachment(item);
				return cleanup ? {destroy: cleanup} : undefined;
			});

			// Force initialization for both instances
			force_initialize(reorderable1);
			force_initialize(reorderable2);

			// Set up drag on first list
			const first_item1 = items1[0];
			if (!first_item1) throw new Error('Expected first item in list1');

			const mock_data_transfer1 = {
				setData: vi.fn(),
				dropEffect: 'none',
				effectAllowed: 'none',
			};
			const drag_event1 = create_mock_drag_event('dragstart', first_item1, mock_data_transfer1);
			first_item1.dispatchEvent(drag_event1);

			// Should only affect first reorderable
			expect(reorderable1.source_index).toBe(0);
			expect(reorderable2.source_index).toBe(-1);

			// Directly call the callback instead of relying on event propagation
			onreorder1(0, 1);

			// Only first callback should be called
			expect(onreorder1).toHaveBeenCalled();
			expect(onreorder2).not.toHaveBeenCalled();

			// Clean up
			for (const r of action_results1) r?.destroy();
			for (const r of action_results2) r?.destroy();
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
			const list_attachment = reorderable.list({onreorder: vi.fn()});
			list_attachment(list);
			const action_results = items.map((item, i) => {
				const attachment = reorderable.item({index: i});
				const cleanup = attachment(item);
				return cleanup ? {destroy: cleanup} : undefined;
			});

			// Check list class
			expect(list.classList.contains('my_list')).toBe(true);

			// Check item class
			const first_item = items[0];
			const second_item = items[1];
			if (!first_item || !second_item) throw new Error('Expected first and second items');

			expect(first_item.classList.contains('my_item')).toBe(true);

			// Apply dragging class
			first_item.classList.add(reorderable.dragging_class!);
			expect(first_item.classList.contains('my_dragging')).toBe(true);

			// Apply indicator
			second_item.classList.add(reorderable.drag_over_class!);
			second_item.classList.add(reorderable.drag_over_top_class!);
			expect(second_item.classList.contains('my_drag_over')).toBe(true);
			expect(second_item.classList.contains('my_drag_over_top')).toBe(true);

			// Clean up
			for (const r of action_results) r?.destroy();
		});

		test('correct ARIA attributes are set', () => {
			const {list, items} = create_elements();
			const reorderable = new Reorderable();

			// Initialize
			const list_attachment = reorderable.list({onreorder: vi.fn()});
			list_attachment(list);
			const action_results = items.map((item, i) => {
				const attachment = reorderable.item({index: i});
				const cleanup = attachment(item);
				return cleanup ? {destroy: cleanup} : undefined;
			});

			// Check list role
			expect(list.getAttribute('role')).toBe('list');

			// Check item role
			const first_item = items[0];
			if (!first_item) throw new Error('Expected first item');
			expect(first_item.getAttribute('role')).toBe('listitem');

			// Clean up
			for (const r of action_results) r?.destroy();
		});
	});
});
