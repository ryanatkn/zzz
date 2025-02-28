import type {Action} from 'svelte/action';
import {on} from 'svelte/events';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

export type Reorderable_Direction = 'horizontal' | 'vertical';

/**
 * Drop positions on the box model.
 */
export type Reorderable_Drop_Position = 'none' | 'top' | 'bottom' | 'left' | 'right';

/**
 * Valid drop positions, excluding 'none'
 */
export type Reorderable_Valid_Drop_Position = Exclude<Reorderable_Drop_Position, 'none'>;

/**
 * Styling configuration for reorderable components
 */
export interface Reorderable_Style_Config {
	item_class: string;
	dragging_class: string;
	drag_over_class: string;
	drag_over_top_class: string;
	drag_over_bottom_class: string;
	drag_over_left_class: string;
	drag_over_right_class: string;
	invalid_drop_class: string;
}

/**
 * Partial styling configuration used for updates
 */
export type Reorderable_Style_Config_Partial = Partial<Reorderable_Style_Config>;

/**
 * Parameters for reorderable_list action
 */
export interface Reorderable_List_Params extends Reorderable_Style_Config_Partial {
	onreorder: (from_index: number, to_index: number) => void;
	list_class?: string;
	can_reorder?: (from_index: number, to_index: number) => boolean;
}

/**
 * Parameters for reorderable_item action
 */
export interface Reorderable_Item_Params extends Reorderable_Style_Config_Partial {
	index: number;
}

/**
 * State between list and item actions
 */
export class Reorderable_Context {
	source_index: number = -1;
	direction: Reorderable_Direction;
	onreorder: (from_index: number, to_index: number) => void;
	can_reorder?: (from_index: number, to_index: number) => boolean;

	// Styling configuration
	item_class: string;
	dragging_class: string;
	drag_over_class: string;
	drag_over_top_class: string;
	drag_over_bottom_class: string;
	drag_over_left_class: string;
	drag_over_right_class: string;
	invalid_drop_class: string;

	constructor(
		onreorder: (from_index: number, to_index: number) => void,
		direction: Reorderable_Direction,
		can_reorder?: (from_index: number, to_index: number) => boolean,
		styles?: Reorderable_Style_Config_Partial,
	) {
		this.onreorder = onreorder;
		this.direction = direction;
		this.can_reorder = can_reorder;

		// Initialize with defaults
		this.item_class = ITEM_CLASS_DEFAULT;
		this.dragging_class = DRAGGING_CLASS_DEFAULT;
		this.drag_over_class = DRAG_OVER_CLASS_DEFAULT;
		this.drag_over_top_class = DRAG_OVER_TOP_CLASS_DEFAULT;
		this.drag_over_bottom_class = DRAG_OVER_BOTTOM_CLASS_DEFAULT;
		this.drag_over_left_class = DRAG_OVER_LEFT_CLASS_DEFAULT;
		this.drag_over_right_class = DRAG_OVER_RIGHT_CLASS_DEFAULT;
		this.invalid_drop_class = INVALID_DROP_CLASS_DEFAULT;

		// Apply custom styles if provided
		if (styles) {
			this.update_styles(styles);
		}
	}

	// Helper to update styling options
	update_styles(styles: Reorderable_Style_Config_Partial): void {
		if (styles.item_class !== undefined) this.item_class = styles.item_class;
		if (styles.dragging_class !== undefined) this.dragging_class = styles.dragging_class;
		if (styles.drag_over_class !== undefined) this.drag_over_class = styles.drag_over_class;
		if (styles.drag_over_top_class !== undefined)
			this.drag_over_top_class = styles.drag_over_top_class;
		if (styles.drag_over_bottom_class !== undefined)
			this.drag_over_bottom_class = styles.drag_over_bottom_class;
		if (styles.drag_over_left_class !== undefined)
			this.drag_over_left_class = styles.drag_over_left_class;
		if (styles.drag_over_right_class !== undefined)
			this.drag_over_right_class = styles.drag_over_right_class;
		if (styles.invalid_drop_class !== undefined)
			this.invalid_drop_class = styles.invalid_drop_class;
	}

	/**
	 * Helper to determine the drop position based on source and target indices and layout direction
	 */
	get_drop_position(source_index: number, target_index: number): Reorderable_Valid_Drop_Position {
		if (this.direction === 'horizontal') {
			// For horizontal layouts
			return source_index > target_index ? 'left' : 'right';
		} else {
			// For vertical layouts
			return source_index > target_index ? 'top' : 'bottom';
		}
	}

	/**
	 * Helper to calculate the target index based on source, current index, and position
	 */
	calculate_target_index(
		source_index: number,
		current_index: number,
		position: Reorderable_Valid_Drop_Position,
	): number {
		let target_index = current_index;

		// Adjust based on drop position
		if (position === 'bottom' || position === 'right') {
			target_index += 1;
		}

		// Adjust target index when moving from earlier position
		if (source_index < current_index) {
			target_index -= 1;
		}

		return target_index;
	}

	/**
	 * Check if reordering is allowed between the two indices
	 */
	is_reorder_allowed(source_index: number, target_index: number): boolean {
		return !this.can_reorder || this.can_reorder(source_index, target_index);
	}
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
export const INVALID_DROP_CLASS_DEFAULT = 'invalid_drop';

/**
 * Enhanced helper to detect layout direction - supports both flex and grid
 */
const detect_direction = (element: HTMLElement): Reorderable_Direction => {
	const computed_style = window.getComputedStyle(element);
	const display = computed_style.display;

	// Check for grid layouts
	if (display === 'grid' || display === 'inline-grid') {
		const grid_auto_flow = computed_style.gridAutoFlow;
		// For grid layouts, "row" flow means items flow horizontally, "column" flow means items flow vertically
		return grid_auto_flow.includes('column') ? 'vertical' : 'horizontal';
	}

	// Check for flex layouts
	if (display === 'flex' || display === 'inline-flex') {
		const flex_direction = computed_style.flexDirection;
		return flex_direction.startsWith('row') ? 'horizontal' : 'vertical';
	}

	// For all other layouts, default to vertical
	return 'vertical';
};

/**
 * Extract style parameters from action parameters
 */
const extract_style_params = (
	params: Partial<Reorderable_Style_Config>,
): Reorderable_Style_Config_Partial => ({
	item_class: params.item_class,
	dragging_class: params.dragging_class,
	drag_over_class: params.drag_over_class,
	drag_over_top_class: params.drag_over_top_class,
	drag_over_bottom_class: params.drag_over_bottom_class,
	drag_over_left_class: params.drag_over_left_class,
	drag_over_right_class: params.drag_over_right_class,
	invalid_drop_class: params.invalid_drop_class,
});

/**
 * Find the parent list's context
 */
const get_reorderable_context = (node: HTMLElement): Reorderable_Context | undefined => {
	// Traverse up to find list element with a context
	let el = node.parentElement;
	while (el) {
		const ctx = contexts.get(el);
		if (ctx) return ctx;
		el = el.parentElement;
	}
	return undefined;
};

/**
 * Action for a reorderable list container
 */
export const reorderable_list: Action<HTMLElement, Reorderable_List_Params> = (node, params) => {
	// Detect the layout direction
	const direction = detect_direction(node);

	// Create context for this list with default values
	const context = new Reorderable_Context(
		params.onreorder,
		direction,
		params.can_reorder,
		extract_style_params(params),
	);

	// Store the context for items to access
	contexts.set(node, context);

	// Use let for list_class so it can be updated and correctly cleaned up
	let list_class = params.list_class || LIST_CLASS_DEFAULT;
	node.classList.add(list_class);

	// Add basic accessibility attribute
	node.setAttribute('role', 'list');

	// Only listening for dragover at the container level to prevent default
	const cleanup_dragover = on(node, 'dragover', (e) => {
		e.preventDefault();
	});

	return {
		update(new_params) {
			// Update the callback directly in the context
			context.onreorder = new_params.onreorder;
			context.can_reorder = new_params.can_reorder;

			// Update direction in case layout changes
			context.direction = detect_direction(node);

			// Update styling options
			context.update_styles(extract_style_params(new_params));

			// Handle class changes if provided
			const new_list_class = new_params.list_class || LIST_CLASS_DEFAULT;
			if (new_list_class !== list_class) {
				node.classList.remove(list_class);
				node.classList.add(new_list_class);
				list_class = new_list_class; // Update the variable for correct cleanup
			}
		},
		destroy() {
			cleanup_dragover();
			contexts.delete(node);
			node.classList.remove(list_class);
			node.removeAttribute('role');
		},
	};
};

/**
 * Action for a reorderable item
 */
export const reorderable_item: Action<HTMLElement, Reorderable_Item_Params> = (node, params) => {
	// The current index of this item
	let {index} = params;

	// Track active elements that have indicators for more efficient clearing
	let active_indicator_element: HTMLElement | null = null;

	// Track last known indicator state to avoid redundant DOM updates
	let current_indicator: Reorderable_Drop_Position = 'none';

	// Use mutable bindings for classes so they can be updated
	let item_class = params.item_class !== undefined ? params.item_class : ITEM_CLASS_DEFAULT;
	let dragging_class =
		params.dragging_class !== undefined ? params.dragging_class : DRAGGING_CLASS_DEFAULT;
	let drag_over_class =
		params.drag_over_class !== undefined ? params.drag_over_class : DRAG_OVER_CLASS_DEFAULT;
	let drag_over_top_class =
		params.drag_over_top_class !== undefined
			? params.drag_over_top_class
			: DRAG_OVER_TOP_CLASS_DEFAULT;
	let drag_over_bottom_class =
		params.drag_over_bottom_class !== undefined
			? params.drag_over_bottom_class
			: DRAG_OVER_BOTTOM_CLASS_DEFAULT;
	let drag_over_left_class =
		params.drag_over_left_class !== undefined
			? params.drag_over_left_class
			: DRAG_OVER_LEFT_CLASS_DEFAULT;
	let drag_over_right_class =
		params.drag_over_right_class !== undefined
			? params.drag_over_right_class
			: DRAG_OVER_RIGHT_CLASS_DEFAULT;
	let invalid_drop_class =
		params.invalid_drop_class !== undefined
			? params.invalid_drop_class
			: INVALID_DROP_CLASS_DEFAULT;

	// Add the reorderable_item class automatically
	node.classList.add(item_class);

	// Add basic accessibility attribute
	node.setAttribute('role', 'listitem');

	// Make the item draggable
	node.setAttribute('draggable', 'true');

	// Efficiently clear only the active element
	const clear_indicators = () => {
		if (active_indicator_element) {
			active_indicator_element.classList.remove(
				drag_over_class,
				drag_over_top_class,
				drag_over_bottom_class,
				drag_over_left_class,
				drag_over_right_class,
				invalid_drop_class,
			);
			active_indicator_element = null;
		}
	};

	// More efficient indicator update that only changes what's needed
	const update_indicator = (
		element: HTMLElement,
		new_indicator: Reorderable_Drop_Position,
		is_valid = true,
	) => {
		// No change, skip update
		if (element === active_indicator_element && new_indicator === current_indicator) return;

		// Clear existing indicator on previous element if needed
		clear_indicators();

		// Apply new indicator classes if needed
		if (new_indicator !== 'none') {
			element.classList.add(drag_over_class);

			// Add invalid drop class if needed
			if (!is_valid) {
				element.classList.add(invalid_drop_class);
				active_indicator_element = element;
				current_indicator = new_indicator;
				return;
			}

			// Add specific direction class
			switch (new_indicator) {
				case 'top':
					element.classList.add(drag_over_top_class);
					break;
				case 'bottom':
					element.classList.add(drag_over_bottom_class);
					break;
				case 'left':
					element.classList.add(drag_over_left_class);
					break;
				case 'right':
					element.classList.add(drag_over_right_class);
					break;
				default:
					throw new Unreachable_Error(new_indicator);
			}

			// Update the active element
			active_indicator_element = element;
		}

		current_indicator = new_indicator;
	};

	// Handle drag start
	const handle_dragstart = (e: DragEvent) => {
		if (!e.dataTransfer) return;

		// Get list context
		const context = get_reorderable_context(node);
		if (!context) return;

		// Store the dragged item's index
		context.source_index = index;

		// Check if we should use context class names or local ones
		const effective_dragging_class = context.dragging_class;

		// Add dragging style
		node.classList.add(effective_dragging_class);

		// Required for Firefox
		e.dataTransfer.effectAllowed = 'move';
		e.dataTransfer.setData('text/plain', '');
	};

	// Handle drag end
	const handle_dragend = () => {
		// Get context to check if we had a source index
		const context = get_reorderable_context(node);

		// Use context class if available
		const effective_dragging_class = context?.dragging_class || dragging_class;

		// Remove dragging style
		node.classList.remove(effective_dragging_class);

		// Reset indicators
		clear_indicators();

		// Reset source index if we have a context
		if (context) {
			context.source_index = -1;
		}

		current_indicator = 'none';
	};

	// Handle drag over
	const handle_dragover = (e: DragEvent) => {
		e.preventDefault();

		// Get list context
		const context = get_reorderable_context(node);
		if (!context || context.source_index === index || context.source_index === -1) return;

		// Get drop position based on relative indices
		const position = context.get_drop_position(context.source_index, index);

		// Calculate the target index
		const target_index = context.calculate_target_index(context.source_index, index, position);

		// Check if reordering is allowed
		const is_allowed = context.is_reorder_allowed(context.source_index, target_index);

		// Update indicator with the new position and validity
		update_indicator(node, position, is_allowed);

		if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';
	};

	// Handle drop
	const handle_drop = (e: DragEvent) => {
		e.preventDefault();

		// Get list context
		const context = get_reorderable_context(node);
		if (!context || context.source_index === -1) return;

		const source_index = context.source_index;

		// Don't allow dragging to self
		if (source_index === index) {
			// Clean up and return without reordering
			clear_indicators();
			context.source_index = -1;
			return;
		}

		// Get drop position based on relative indices
		const position = context.get_drop_position(source_index, index);

		// Calculate target index using the context method
		let target_index = context.calculate_target_index(source_index, index, position);

		// Ensure target index is valid
		const parent = node.parentElement;
		const max_index = parent ? parent.children.length - 1 : 0;
		if (target_index < 0) target_index = 0;
		if (target_index > max_index + 1) target_index = max_index + 1;

		// Check if reordering is allowed
		if (!context.is_reorder_allowed(source_index, target_index)) {
			// Not allowed - just clean up
			clear_indicators();
			context.source_index = -1;
			return;
		}

		// Perform the actual reordering
		context.onreorder(source_index, target_index);

		// Clear indicators
		clear_indicators();

		// Reset drag state
		context.source_index = -1;
	};

	// Handle drag leave - optimize to avoid unnecessary updates
	const handle_dragleave = (e: DragEvent) => {
		// Check if we're actually leaving this element (not its children)
		const related_target = e.relatedTarget as Node | null;
		if (related_target && node.contains(related_target)) {
			return;
		}

		// Only clear if we currently have indicators
		if (current_indicator !== 'none') {
			clear_indicators();
			current_indicator = 'none';
		}
	};

	// Set up event listeners
	const cleanup_dragstart = on(node, 'dragstart', handle_dragstart, {passive: true});
	const cleanup_dragend = on(node, 'dragend', handle_dragend, {passive: true});
	const cleanup_dragover = on(node, 'dragover', handle_dragover); // Not passive - needs preventDefault
	const cleanup_drop = on(node, 'drop', handle_drop); // Not passive - needs preventDefault
	const cleanup_dragleave = on(node, 'dragleave', handle_dragleave, {passive: true});

	return {
		update(new_params) {
			// Update the index if it changes
			index = new_params.index;

			// Handle all possible class changes with proper undefined checks
			if (new_params.item_class !== undefined) {
				node.classList.remove(item_class);
				node.classList.add(new_params.item_class);
				item_class = new_params.item_class;
			}

			// Update other class names if provided
			if (new_params.dragging_class !== undefined) {
				dragging_class = new_params.dragging_class;
			}
			if (new_params.drag_over_class !== undefined) {
				drag_over_class = new_params.drag_over_class;
			}
			if (new_params.drag_over_top_class !== undefined) {
				drag_over_top_class = new_params.drag_over_top_class;
			}
			if (new_params.drag_over_bottom_class !== undefined) {
				drag_over_bottom_class = new_params.drag_over_bottom_class;
			}
			if (new_params.drag_over_left_class !== undefined) {
				drag_over_left_class = new_params.drag_over_left_class;
			}
			if (new_params.drag_over_right_class !== undefined) {
				drag_over_right_class = new_params.drag_over_right_class;
			}
			if (new_params.invalid_drop_class !== undefined) {
				invalid_drop_class = new_params.invalid_drop_class;
			}
		},
		destroy() {
			// Clean up all event listeners
			cleanup_dragstart();
			cleanup_dragend();
			cleanup_dragover();
			cleanup_drop();
			cleanup_dragleave();

			// Remove the class we added
			node.classList.remove(item_class);

			// Remove accessibility attributes
			node.removeAttribute('role');

			// Remove draggable attribute
			node.removeAttribute('draggable');
		},
	};
};
