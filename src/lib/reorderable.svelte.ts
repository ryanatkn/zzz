import type {Action} from 'svelte/action';
import {on} from 'svelte/events';

/**
 * State between list and item actions
 */
export interface Drag_Context {
	dragged_index: number;
	onreorder: (from_index: number, to_index: number) => void;
}

// WeakMap ensures contexts are garbage collected when elements are removed
const contexts: WeakMap<HTMLElement, Drag_Context> = new WeakMap();

/**
 * Action for a reorderable list container
 */
export const reorderable_list: Action<
	HTMLElement,
	{onreorder: (from_index: number, to_index: number) => void}
> = (node, params) => {
	// Create context for this list with default values
	const context: Drag_Context = {
		dragged_index: -1,
		onreorder: params.onreorder,
	};

	// Store the context for items to access
	contexts.set(node, context);

	// Only listening for dragover at the container level to prevent default
	const handle_dragover = (e: DragEvent) => {
		e.preventDefault();
	};

	const cleanup_dragover = on(node, 'dragover', handle_dragover);

	return {
		update(new_params) {
			// Update the callback directly in the context
			context.onreorder = new_params.onreorder;
		},
		destroy() {
			cleanup_dragover();
			contexts.delete(node);
		},
	};
};

export const ITEM_CLASS_DEFAULT = 'reorderable_item';

/**
 * Action for a reorderable item
 */
export const reorderable_item: Action<HTMLElement, {index: number; item_class?: string}> = (
	node,
	params,
) => {
	// The current index of this item
	let {index} = params;

	// Default class to use if none provided
	const item_class = params.item_class || ITEM_CLASS_DEFAULT;

	// Track last known indicator state to avoid redundant DOM updates
	let current_indicator: 'none' | 'before' | 'after' = 'none';

	// Track RAF to avoid multiple renders in the same frame
	let raf_id: number | null = null;

	// Debounce rate in milliseconds (tune as needed)
	const update_delay = 17; // TODO instead of this, can we just use RAF to batch on one frame and simplify?
	let last_update = 0;

	// Add the reorderable_item class automatically
	node.classList.add(item_class);

	// Find the parent list's context
	const get_context = (): Drag_Context | undefined => {
		// Traverse up to find list element with a context
		let el = node.parentElement;
		while (el) {
			const ctx = contexts.get(el);
			if (ctx) return ctx;
			el = el.parentElement;
		}
		return undefined;
	};

	// Make the item draggable
	node.setAttribute('draggable', 'true');

	// Clear visual indicators on all siblings
	const clear_indicators = () => {
		// Get parent element
		const parent = node.parentElement;
		if (!parent) return;

		// Clear indicators on all children
		Array.from(parent.children).forEach((child) => {
			if (child instanceof HTMLElement) {
				child.classList.remove('drag_over', 'drag_over_before', 'drag_over_after');
			}
		});
	};

	// More efficient indicator update that only changes what's needed
	const update_indicator = (new_indicator: 'none' | 'before' | 'after') => {
		// No change, skip update
		if (new_indicator === current_indicator) return;

		// Clear existing indicator classes
		node.classList.remove('drag_over', 'drag_over_before', 'drag_over_after');

		// Apply new indicator classes if needed
		if (new_indicator !== 'none') {
			node.classList.add('drag_over');
			node.classList.add(`drag_over_${new_indicator}`);
		}

		current_indicator = new_indicator;
	};

	// Handle drag start
	const handle_dragstart = (e: DragEvent) => {
		if (!e.dataTransfer) return;

		// Get list context
		const context = get_context();
		if (!context) return;

		// Store the dragged item's index
		context.dragged_index = index;

		// Add dragging style
		node.classList.add('dragging');

		// Required for Firefox
		e.dataTransfer.effectAllowed = 'move';
		e.dataTransfer.setData('text/plain', '');
	};

	// Handle drag end
	const handle_dragend = () => {
		// Remove dragging style
		node.classList.remove('dragging');

		// Clear any pending indicator updates
		if (raf_id !== null) {
			cancelAnimationFrame(raf_id);
			raf_id = null;
		}

		// Reset indicators
		update_indicator('none');
		clear_indicators();

		// Reset dragged index
		const context = get_context();
		if (context) {
			context.dragged_index = -1;
		}

		current_indicator = 'none';
	};

	// Handle drag over with efficiency improvements
	const handle_dragover = (e: DragEvent) => {
		e.preventDefault();

		// Get list context
		const context = get_context();
		if (!context || context.dragged_index === index || context.dragged_index === -1) return;

		// Throttle updates to reduce DOM thrashing
		const now = Date.now();
		if (now - last_update < update_delay) return;
		last_update = now;

		if (raf_id !== null) {
			cancelAnimationFrame(raf_id);
			raf_id = null;
		}

		raf_id = requestAnimationFrame(() => {
			// Calculate if the cursor is in the top or bottom half of the item
			const rect = node.getBoundingClientRect();
			const height = rect.height;

			// Buffer zone - 20% from top and bottom
			const buffer = height * 0.2;
			const y_position = e.clientY - rect.top;

			let new_indicator: 'before' | 'after';

			// Determine position based on buffer zones
			if (y_position < buffer) {
				new_indicator = 'before';
			} else if (y_position > height - buffer) {
				new_indicator = 'after';
			} else {
				new_indicator = y_position < height / 2 ? 'before' : 'after';
			}

			// Only update DOM if indicator position changed
			update_indicator(new_indicator);

			if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';
			raf_id = null;
		});
	};

	// Handle drop
	const handle_drop = (e: DragEvent) => {
		e.preventDefault();

		// Get list context
		const context = get_context();
		if (!context || context.dragged_index === -1) return;

		// Cancel any pending indicator updates
		if (raf_id !== null) {
			cancelAnimationFrame(raf_id);
			raf_id = null;
		}

		// Calculate if dropping before or after this item using same buffer logic as dragover
		const rect = node.getBoundingClientRect();
		const height = rect.height;
		const buffer = height * 0.2;
		const y_position = e.clientY - rect.top;

		let is_before: boolean;

		if (y_position < buffer) {
			is_before = true;
		} else if (y_position > height - buffer) {
			is_before = false;
		} else {
			is_before = y_position < height / 2;
		}

		// Calculate the target index
		let target_index = is_before ? index : index + 1;

		// Adjust if we're moving an item from before this one
		if (context.dragged_index < index) {
			target_index--;
		}

		// Only reorder if the position is different
		if (target_index !== context.dragged_index) {
			context.onreorder(context.dragged_index, target_index);
		}

		// Clear indicators
		update_indicator('none');
		clear_indicators();

		// Reset drag state
		context.dragged_index = -1;
		current_indicator = 'none';
	};

	// Handle drag leave - optimize to avoid unnecessary updates
	const handle_dragleave = (e: DragEvent) => {
		// Check if we're actually leaving this element (not its children)
		// This prevents unnecessary updates when moving within the element
		const related_target = e.relatedTarget as Node | null;
		if (related_target && node.contains(related_target)) {
			return;
		}

		// Cancel any pending indicator updates
		if (raf_id !== null) {
			cancelAnimationFrame(raf_id);
			raf_id = null;
		}

		// Only update if we currently have indicators
		if (current_indicator !== 'none') {
			update_indicator('none');
		}
	};

	// Set up event listeners
	const cleanup_dragstart = on(node, 'dragstart', handle_dragstart);
	const cleanup_dragend = on(node, 'dragend', handle_dragend);
	const cleanup_dragover = on(node, 'dragover', handle_dragover);
	const cleanup_drop = on(node, 'drop', handle_drop);
	const cleanup_dragleave = on(node, 'dragleave', handle_dragleave);

	return {
		update(new_params) {
			// Update the index if it changes
			index = new_params.index;

			// Handle class changes if provided
			const new_item_class = new_params.item_class || ITEM_CLASS_DEFAULT;
			if (new_item_class !== item_class) {
				node.classList.remove(item_class);
				node.classList.add(new_item_class);
			}
		},
		destroy() {
			// Remove the class we added
			node.classList.remove(item_class);

			// Cancel any pending RAF
			if (raf_id !== null) {
				cancelAnimationFrame(raf_id);
				raf_id = null;
			}

			// Clean up all event listeners
			cleanup_dragstart();
			cleanup_dragend();
			cleanup_dragover();
			cleanup_drop();
			cleanup_dragleave();
		},
	};
};
