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

// Default CSS class names for styling
export const LIST_CLASS_DEFAULT = 'reorderable_list';
export const ITEM_CLASS_DEFAULT = 'reorderable_item';
export const DRAGGING_CLASS_DEFAULT = 'dragging';
export const DRAG_OVER_CLASS_DEFAULT = 'drag_over';
export const DRAG_OVER_BEFORE_CLASS_DEFAULT = 'drag_over_before';
export const DRAG_OVER_AFTER_CLASS_DEFAULT = 'drag_over_after';

/**
 * Action for a reorderable list container
 */
export const reorderable_list: Action<
	HTMLElement,
	{
		onreorder: (from_index: number, to_index: number) => void;
		list_class?: string;
	}
> = (node, params) => {
	// Create context for this list with default values
	const context: Drag_Context = {
		dragged_index: -1,
		onreorder: params.onreorder,
	};

	// Store the context for items to access
	contexts.set(node, context);

	// Use let for list_class so it can be updated and correctly cleaned up
	let list_class = params.list_class || LIST_CLASS_DEFAULT;
	node.classList.add(list_class);

	// Only listening for dragover at the container level to prevent default
	const handle_dragover = (e: DragEvent) => {
		e.preventDefault();
	};

	const cleanup_dragover = on(node, 'dragover', handle_dragover);

	return {
		update(new_params) {
			// Update the callback directly in the context
			context.onreorder = new_params.onreorder;

			// Handle class changes if provided
			const new_list_class = new_params.list_class || LIST_CLASS_DEFAULT;
			if (new_list_class !== list_class) {
				if (node.classList.contains(list_class)) {
					node.classList.remove(list_class);
					node.classList.add(new_list_class);
				}
				list_class = new_list_class; // Update the variable for correct cleanup
			}
		},
		destroy() {
			cleanup_dragover();
			contexts.delete(node);
			node.classList.remove(list_class);
		},
	};
};

/**
 * Helper to determine if a target item is before or after the source item
 * This is more reliable than using movement direction
 */
const is_before_in_dom = (source_index: number, target_index: number): boolean =>
	source_index > target_index;

/**
 * Action for a reorderable item
 */
export const reorderable_item: Action<
	HTMLElement,
	{
		index: number;
		item_class?: string;
		dragging_class?: string;
		drag_over_class?: string;
		drag_over_before_class?: string;
		drag_over_after_class?: string;
	}
> = (node, params) => {
	// The current index of this item
	let {index} = params;

	// Use provided classes or defaults
	const item_class = params.item_class || ITEM_CLASS_DEFAULT;
	const dragging_class = params.dragging_class || DRAGGING_CLASS_DEFAULT;
	const drag_over_class = params.drag_over_class || DRAG_OVER_CLASS_DEFAULT;
	const drag_over_before_class = params.drag_over_before_class || DRAG_OVER_BEFORE_CLASS_DEFAULT;
	const drag_over_after_class = params.drag_over_after_class || DRAG_OVER_AFTER_CLASS_DEFAULT;

	// Track last known indicator state to avoid redundant DOM updates
	let current_indicator: 'none' | 'before' | 'after' = 'none';

	// Track RAF to avoid multiple renders in the same frame
	let raf_id: number | null = null;

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
				child.classList.remove(drag_over_class, drag_over_before_class, drag_over_after_class);
			}
		});
	};

	// More efficient indicator update that only changes what's needed
	const update_indicator = (new_indicator: 'none' | 'before' | 'after') => {
		// No change, skip update
		if (new_indicator === current_indicator) return;

		// Clear existing indicator classes
		node.classList.remove(drag_over_class, drag_over_before_class, drag_over_after_class);

		// Apply new indicator classes if needed
		if (new_indicator !== 'none') {
			node.classList.add(drag_over_class);
			node.classList.add(
				new_indicator === 'before' ? drag_over_before_class : drag_over_after_class,
			);
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
		node.classList.add(dragging_class);

		// Required for Firefox
		e.dataTransfer.effectAllowed = 'move';
		e.dataTransfer.setData('text/plain', '');
	};

	// Handle drag end
	const handle_dragend = () => {
		// Remove dragging style
		node.classList.remove(dragging_class);

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

	// Handle drag over with RAF for efficiency
	const handle_dragover = (e: DragEvent) => {
		e.preventDefault();

		// Get list context
		const context = get_context();
		if (!context || context.dragged_index === index || context.dragged_index === -1) return;

		// Use RAF to batch updates
		if (raf_id !== null) {
			return; // Already have a pending update
		}

		raf_id = requestAnimationFrame(() => {
			// Determine position based on DOM order, not movement direction
			// This eliminates flickering by making the decision consistent
			const dragged_index = context.dragged_index;
			const target_is_before = is_before_in_dom(dragged_index, index);

			// If target is before dragged item, insert before; otherwise after
			const new_indicator = target_is_before ? 'before' : 'after';

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

		const dragged_index = context.dragged_index;

		// Determine if drop is before or after based on DOM order
		const target_is_before = is_before_in_dom(dragged_index, index);
		const is_before = target_is_before;

		// Calculate the target index
		let target_index = is_before ? index : index + 1;

		// Adjust if we're moving an item from before this one
		if (dragged_index < index) {
			target_index--;
		}

		// Only reorder if the position is different and not just consecutive
		if (
			target_index !== dragged_index &&
			!(
				Math.abs(target_index - dragged_index) === 1 &&
				((dragged_index > target_index && !is_before) ||
					(dragged_index < target_index && is_before))
			)
		) {
			context.onreorder(dragged_index, target_index);
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

	// Set up event listeners with passive option where appropriate
	const cleanup_dragstart = on(node, 'dragstart', handle_dragstart, {passive: true});
	const cleanup_dragend = on(node, 'dragend', handle_dragend, {passive: true});
	const cleanup_dragover = on(node, 'dragover', handle_dragover); // Not passive - needs preventDefault
	const cleanup_drop = on(node, 'drop', handle_drop); // Not passive - needs preventDefault
	const cleanup_dragleave = on(node, 'dragleave', handle_dragleave, {passive: true});

	return {
		update(new_params) {
			// Update the index if it changes
			index = new_params.index;

			// Handle class changes if provided
			const new_item_class = new_params.item_class || ITEM_CLASS_DEFAULT;
			if (new_item_class !== item_class && node.classList.contains(item_class)) {
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
