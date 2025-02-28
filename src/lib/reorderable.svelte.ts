import type {Action} from 'svelte/action';
import {on} from 'svelte/events';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

export type Direction = 'horizontal' | 'vertical';

/**
 * Drop positions on the box model.
 */
export type Drop_Position = 'none' | 'top' | 'bottom' | 'left' | 'right';

/**
 * Valid drop positions, excluding 'none'
 */
export type Valid_Drop_Position = Exclude<Drop_Position, 'none'>;

/**
 * State between list and item actions
 */
export interface Reorderable_Context {
	source_index: number;
	direction: Direction;
	onreorder: (from_index: number, to_index: number) => void;
}

// WeakMap ensures contexts are garbage collected when elements are removed
const contexts: WeakMap<HTMLElement, Reorderable_Context> = new WeakMap();

// Default CSS class names for styling
export const LIST_CLASS_DEFAULT = 'reorderable_list';
export const ITEM_CLASS_DEFAULT = 'reorderable_item';
export const DRAGGING_CLASS_DEFAULT = 'dragging';
export const DRAG_OVER_CLASS_DEFAULT = 'drag_over';
export const DRAG_OVER_TOP_CLASS_DEFAULT = 'drag_over_top';
export const DRAG_OVER_BOTTOM_CLASS_DEFAULT = 'drag_over_bottom';
export const DRAG_OVER_LEFT_CLASS_DEFAULT = 'drag_over_left';
export const DRAG_OVER_RIGHT_CLASS_DEFAULT = 'drag_over_right';

/**
 * Helper to detect if a layout is horizontal
 */
const detect_direction = (element: HTMLElement): Direction => {
	const computed_style = window.getComputedStyle(element);
	const display = computed_style.display;
	const flex_direction = computed_style.flexDirection;

	// Check if it's a flex container with row direction
	if (
		(display === 'flex' || display === 'inline-flex') &&
		(flex_direction === 'row' || flex_direction === 'row-reverse')
	) {
		return 'horizontal';
	}

	// For all other layouts, assume vertical
	return 'vertical';
};

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
	// Detect the layout direction
	const direction = detect_direction(node);

	// Create context for this list with default values
	const context: Reorderable_Context = {
		source_index: -1,
		direction,
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

			// Update direction in case layout changes
			context.direction = detect_direction(node);

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
 * Helper to determine the drop position based on source and target indices and layout direction
 */
const get_drop_position = (
	source_index: number,
	target_index: number,
	direction: Direction,
): Valid_Drop_Position => {
	if (direction === 'horizontal') {
		// For horizontal layouts
		return source_index > target_index ? 'left' : 'right';
	} else {
		// For vertical layouts
		return source_index > target_index ? 'top' : 'bottom';
	}
};

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
		drag_over_top_class?: string;
		drag_over_bottom_class?: string;
		drag_over_left_class?: string;
		drag_over_right_class?: string;
	}
> = (node, params) => {
	// The current index of this item
	let {index} = params;

	// Use provided classes or defaults
	const item_class = params.item_class || ITEM_CLASS_DEFAULT;
	const dragging_class = params.dragging_class || DRAGGING_CLASS_DEFAULT;
	const drag_over_class = params.drag_over_class || DRAG_OVER_CLASS_DEFAULT;
	const drag_over_top_class = params.drag_over_top_class || DRAG_OVER_TOP_CLASS_DEFAULT;
	const drag_over_bottom_class = params.drag_over_bottom_class || DRAG_OVER_BOTTOM_CLASS_DEFAULT;
	const drag_over_left_class = params.drag_over_left_class || DRAG_OVER_LEFT_CLASS_DEFAULT;
	const drag_over_right_class = params.drag_over_right_class || DRAG_OVER_RIGHT_CLASS_DEFAULT;

	// Track last known indicator state to avoid redundant DOM updates
	let current_indicator: Drop_Position = 'none';

	// Add the reorderable_item class automatically
	node.classList.add(item_class);

	// Find the parent list's context
	const get_context = (): Reorderable_Context | undefined => {
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
				child.classList.remove(
					drag_over_class,
					drag_over_top_class,
					drag_over_bottom_class,
					drag_over_left_class,
					drag_over_right_class,
				);
			}
		});
	};

	// More efficient indicator update that only changes what's needed
	const update_indicator = (new_indicator: Drop_Position) => {
		// No change, skip update
		if (new_indicator === current_indicator) return;

		// Clear existing indicator classes
		node.classList.remove(
			drag_over_class,
			drag_over_top_class,
			drag_over_bottom_class,
			drag_over_left_class,
			drag_over_right_class,
		);

		// Apply new indicator classes if needed
		if (new_indicator !== 'none') {
			node.classList.add(drag_over_class);

			// Add specific direction class
			switch (new_indicator) {
				case 'top':
					node.classList.add(drag_over_top_class);
					break;
				case 'bottom':
					node.classList.add(drag_over_bottom_class);
					break;
				case 'left':
					node.classList.add(drag_over_left_class);
					break;
				case 'right':
					node.classList.add(drag_over_right_class);
					break;
				default:
					throw new Unreachable_Error(new_indicator);
			}
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
		context.source_index = index;

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

		// Reset indicators
		update_indicator('none');
		clear_indicators();

		// Reset source index
		const context = get_context();
		if (context) {
			context.source_index = -1;
		}

		current_indicator = 'none';
	};

	// Handle drag over
	const handle_dragover = (e: DragEvent) => {
		e.preventDefault();

		// Get list context
		const context = get_context();
		if (!context || context.source_index === index || context.source_index === -1) return;

		// Get drop position based on relative indices, not mouse coordinates
		const position = get_drop_position(context.source_index, index, context.direction);

		// Update indicator with the new position - only if it's different
		update_indicator(position);

		if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';
	};

	// Handle drop
	const handle_drop = (e: DragEvent) => {
		e.preventDefault();

		// Get list context
		const context = get_context();
		if (!context || context.source_index === -1) return;

		const source_index = context.source_index;

		// Don't allow dragging to self - this fixes the bug
		if (source_index === index) {
			// Clean up and return without reordering
			update_indicator('none');
			clear_indicators();
			context.source_index = -1;
			current_indicator = 'none';
			return;
		}

		// Get drop position based on relative indices
		const position = get_drop_position(source_index, index, context.direction);

		// Determine target index based on position
		let target_index = index;
		if (position === 'bottom' || position === 'right') {
			target_index += 1;
		}

		// Adjust target index when moving from earlier position
		if (source_index < index) {
			target_index -= 1;
		}

		// Perform the reordering
		context.onreorder(source_index, target_index);

		// Clear indicators
		update_indicator('none');
		clear_indicators();

		// Reset drag state
		context.source_index = -1;
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

			// Clean up all event listeners
			cleanup_dragstart();
			cleanup_dragend();
			cleanup_dragover();
			cleanup_drop();
			cleanup_dragleave();
		},
	};
};
