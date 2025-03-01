import type {Action} from 'svelte/action';
import {on} from 'svelte/events';
import {onDestroy} from 'svelte';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';
import {
	detect_direction,
	get_drop_position,
	calculate_target_index,
	is_reorder_allowed,
	update_styles_excluding_direction,
	validate_target_index,
} from '$lib/reorderable_helpers.js';
import {DEV} from 'esm-env';

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
 * Parameters for list action
 */
export interface Reorderable_List_Params {
	onreorder: (from_index: number, to_index: number) => void;
	list_class?: string;
	can_reorder?: (from_index: number, to_index: number) => boolean;
}

/**
 * Parameters for item action
 */
export interface Reorderable_Item_Params {
	index: number;
}

/**
 * Additional configuration options for Reorderable
 */
export interface Reorderable_Options extends Reorderable_Style_Config_Partial {
	direction?: Reorderable_Direction;
	autodestroy?: boolean;
}

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
 * Encapsulates drag and drop reordering functionality for a single list
 */
export class Reorderable implements Reorderable_Style_Config {
	// Single list state
	list_node: HTMLElement | null = null;
	list_params: Reorderable_List_Params | null = null;

	// Tracking state
	source_index = -1;
	// Use WeakMap to avoid memory leaks when elements are removed
	items: WeakMap<HTMLElement, number> = new WeakMap();
	cleanup_handlers: Array<() => void> = [];
	reordering_in_progress = false;
	dragged_element: HTMLElement | null = null;

	// Direction for drag/drop positioning
	direction: Reorderable_Direction;

	// Track active states for drag operations
	active_indicator_element: HTMLElement | null = null;
	current_indicator: Reorderable_Drop_Position = 'none';

	// Styling configuration
	item_class: string;
	dragging_class: string;
	drag_over_class: string;
	drag_over_top_class: string;
	drag_over_bottom_class: string;
	drag_over_left_class: string;
	drag_over_right_class: string;
	invalid_drop_class: string;

	/**
	 * Create a new Reorderable instance
	 * @param options Optional styling and behavior configuration
	 */
	constructor(options?: Reorderable_Options) {
		// Initialize with defaults
		this.item_class = ITEM_CLASS_DEFAULT;
		this.dragging_class = DRAGGING_CLASS_DEFAULT;
		this.drag_over_class = DRAG_OVER_CLASS_DEFAULT;
		this.drag_over_top_class = DRAG_OVER_TOP_CLASS_DEFAULT;
		this.drag_over_bottom_class = DRAG_OVER_BOTTOM_CLASS_DEFAULT;
		this.drag_over_left_class = DRAG_OVER_LEFT_CLASS_DEFAULT;
		this.drag_over_right_class = DRAG_OVER_RIGHT_CLASS_DEFAULT;
		this.invalid_drop_class = INVALID_DROP_CLASS_DEFAULT;
		this.direction = options?.direction || 'vertical';

		// Apply custom styles if provided
		if (options) {
			this.update_styles(options);
		}

		// Auto-destroy with Svelte lifecycle if not disabled
		const autodestroy = options?.autodestroy !== false;
		if (autodestroy) {
			try {
				onDestroy(() => this.destroy());
			} catch (e) {
				// Ignore if not in a Svelte component context
				if (DEV) {
					console.error(
						'Reorderable was created outside of component initialization, if this was intentional set option `autodestroy: false`.',
					);
				}
			}
		}
	}

	/**
	 * Update styling configuration
	 */
	update_styles(styles: Reorderable_Style_Config_Partial): void {
		update_styles_excluding_direction(this, styles);
	}

	/**
	 * Set the direction manually
	 */
	set_direction(direction: Reorderable_Direction): void {
		this.direction = direction;
	}

	/**
	 * Efficiently clear only the active element's indicators
	 */
	clear_indicators(): void {
		if (!this.active_indicator_element) return;

		this.active_indicator_element.classList.remove(
			this.drag_over_class,
			this.drag_over_top_class,
			this.drag_over_bottom_class,
			this.drag_over_left_class,
			this.drag_over_right_class,
			this.invalid_drop_class,
		);
		this.active_indicator_element = null;
		this.current_indicator = 'none';
	}

	/**
	 * More efficient indicator update that only changes what's needed
	 */
	update_indicator(
		element: HTMLElement,
		new_indicator: Reorderable_Drop_Position,
		is_valid = true,
	): void {
		// When hovering over the source element, always clear indicators and return
		if (this.source_index !== -1 && this.items.get(element) === this.source_index) {
			this.clear_indicators();
			return;
		}

		// No change, skip update
		if (element === this.active_indicator_element && new_indicator === this.current_indicator) {
			return;
		}

		// Clear existing indicator on previous element if needed
		this.clear_indicators();

		// Apply new indicator classes if needed
		if (new_indicator !== 'none') {
			element.classList.add(this.drag_over_class);

			// Add invalid drop class if needed
			if (!is_valid) {
				element.classList.add(this.invalid_drop_class);
				this.active_indicator_element = element;
				this.current_indicator = new_indicator;
				return;
			}

			// Add specific direction class
			switch (new_indicator) {
				case 'top':
					element.classList.add(this.drag_over_top_class);
					break;
				case 'bottom':
					element.classList.add(this.drag_over_bottom_class);
					break;
				case 'left':
					element.classList.add(this.drag_over_left_class);
					break;
				case 'right':
					element.classList.add(this.drag_over_right_class);
					break;
				default:
					throw new Unreachable_Error(new_indicator);
			}

			// Update the active element
			this.active_indicator_element = element;
			this.current_indicator = new_indicator;
		}
	}

	/**
	 * Programmatically move an item from one position to another
	 */
	move_item(from_index: number, to_index: number): void {
		if (from_index === to_index) return;

		if (!this.list_params) {
			console.warn('Reorderable.move_item() called without a valid list reference.');
			return;
		}

		// Check if reordering is allowed
		if (!is_reorder_allowed(this.list_params.can_reorder, from_index, to_index)) return;

		// Trigger the reorder callback
		this.list_params.onreorder(from_index, to_index);
	}

	/**
	 * Find an item element from an event
	 */
	#find_item_from_event(event: Event): [HTMLElement, number] | null {
		// Get the target element
		const target = event.target as HTMLElement | null;
		if (!target) return null;

		// Check if the target itself is an item
		if (this.items.has(target)) {
			return [target, this.items.get(target)!];
		}

		// Walk up the DOM to find a parent that's an item
		let current: HTMLElement | null = target;
		while (current) {
			if (this.items.has(current)) {
				return [current, this.items.get(current)!];
			}
			current = current.parentElement;
		}

		return null;
	}

	/**
	 * Set up event handlers for the list using event delegation
	 */
	#setup_list_events(list: HTMLElement): void {
		// Clean up any existing handlers
		this.#cleanup_events();

		// Use event delegation for dragstart event
		const cleanup_dragstart = on(
			list,
			'dragstart',
			(e: DragEvent) => {
				if (!e.dataTransfer) return;

				// Find the item element being dragged
				const found = this.#find_item_from_event(e);
				if (!found) return;

				const [element, index] = found;

				// If reordering is in progress, don't start a new drag
				if (this.reordering_in_progress) {
					e.preventDefault();
					return;
				}

				// Clear any existing drag operation
				this.clear_indicators();
				this.source_index = -1;

				// Set up the new drag operation
				this.source_index = index;
				this.dragged_element = element;

				// Add dragging style
				element.classList.add(this.dragging_class);

				// Required for Firefox
				e.dataTransfer.effectAllowed = 'move';
				e.dataTransfer.setData('text/plain', '');
			},
			{capture: true},
		);

		const cleanup_dragend = on(
			list,
			'dragend',
			(_e: DragEvent) => {
				// Reset the dragged element if it exists
				if (this.dragged_element) {
					this.dragged_element.classList.remove(this.dragging_class);
					this.dragged_element = null;
				}

				// Reset indicators and source tracking
				this.clear_indicators();
				this.source_index = -1;
			},
			{capture: true},
		);

		// Set up dragover handler
		const cleanup_dragover = on(list, 'dragover', (e: DragEvent) => {
			e.preventDefault();
			if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';

			// If no active drag or reordering in progress, return
			if (this.source_index === -1 || this.reordering_in_progress) {
				this.clear_indicators();
				return;
			}

			// Find the item being dragged over
			const found = this.#find_item_from_event(e);
			if (!found) {
				// Not over an item, clear indicators
				this.clear_indicators();
				return;
			}

			const [target_element, item_index] = found;

			// Skip if dragging onto self - always clear indicators
			if (item_index === this.source_index) {
				this.clear_indicators();
				return;
			}

			// Get drop position
			const position = get_drop_position(this.direction, this.source_index, item_index);

			// Calculate target index
			const target_index = calculate_target_index(this.source_index, item_index, position);

			// Check if reordering is allowed
			const allowed = is_reorder_allowed(
				this.list_params?.can_reorder,
				this.source_index,
				target_index,
			);

			// Update indicator
			this.update_indicator(target_element, position, allowed);
		});

		// Set up drop handler
		const cleanup_drop = on(list, 'drop', (e: DragEvent): void => {
			e.preventDefault();

			// Save current state to local variables to avoid race conditions
			const current_source_index = this.source_index;

			// If no active drag or reordering in progress, return
			if (current_source_index === -1 || this.reordering_in_progress) {
				this.clear_indicators();
				return;
			}

			// Find the drop target item
			const found = this.#find_item_from_event(e);
			if (!found) {
				this.clear_indicators();
				this.source_index = -1;
				return;
			}

			const [_target_element, item_index] = found;

			// Skip if dropping on self
			if (item_index === current_source_index) {
				this.clear_indicators();
				this.source_index = -1;
				return;
			}

			// Get drop position
			const position = get_drop_position(this.direction, current_source_index, item_index);

			// Calculate target index
			let target_index = calculate_target_index(current_source_index, item_index, position);

			// Validate target index
			const max_items_count = this.#count_items();
			target_index = validate_target_index(target_index, max_items_count - 1);

			// Check if reordering is allowed
			if (!is_reorder_allowed(this.list_params?.can_reorder, current_source_index, target_index)) {
				this.clear_indicators();
				this.source_index = -1;
				return;
			}

			// Clear state BEFORE performing the reorder
			this.clear_indicators();
			this.source_index = -1;

			// Mark as in the process of reordering
			this.reordering_in_progress = true;

			try {
				// Perform the reordering using the callback
				this.list_params?.onreorder(current_source_index, target_index);

				// We no longer need to sync indices - Svelte's action system will handle this
				// when the items are re-rendered with their new indices
				this.reordering_in_progress = false;
			} catch (error) {
				console.error('Error during reordering:', error);
				this.reordering_in_progress = false;
			}
		});

		// Set up dragleave
		const cleanup_dragleave = on(list, 'dragleave', (e: DragEvent) => {
			const related_target = e.relatedTarget as Node | null;
			if (!related_target || !list.contains(related_target)) {
				this.clear_indicators();
			}
		});

		// Store the cleanup functions
		this.cleanup_handlers = [
			cleanup_dragstart,
			cleanup_dragend,
			cleanup_dragover,
			cleanup_drop,
			cleanup_dragleave,
		];
	}

	/**
	 * Count the number of items currently tracked
	 */
	#count_items(): number {
		let count = 0;
		if (this.list_node) {
			// Count items based on the items tracked by our WeakMap
			// We could optimize this by maintaining a separate count, but this is safer
			const items = this.list_node.querySelectorAll('[role="listitem"]');
			items.forEach((item) => {
				if (this.items.has(item as HTMLElement)) count++;
			});
		}
		return count;
	}

	/**
	 * Clean up event handlers
	 */
	#cleanup_events(): void {
		// Call all cleanup functions
		this.cleanup_handlers.forEach((cleanup) => cleanup());
		// Clear the array
		this.cleanup_handlers = [];
	}

	/**
	 * Action for the list container
	 */
	list: Action<HTMLElement, Reorderable_List_Params> = (node, params) => {
		// Check if we already have a list node
		if (this.list_node && this.list_node !== node) {
			throw new Error('This Reorderable instance is already attached to a different list element.');
		}

		// Clean up previous state if this is a re-initialization
		if (this.list_node === node) {
			this.#cleanup_events();
		}

		// Update direction based on the list's layout if not manually set
		this.direction = detect_direction(node);

		// Store the list params and node
		this.list_params = params;
		this.list_node = node;

		// Reset state - no need to clear items as WeakMap will garbage collect
		// when elements are removed from the DOM
		this.reordering_in_progress = false;
		this.dragged_element = null;
		this.source_index = -1;

		// Set up event handlers
		this.#setup_list_events(node);

		// Add the list class
		const list_class = params.list_class || LIST_CLASS_DEFAULT;
		node.classList.add(list_class);

		// Add accessibility attribute
		node.setAttribute('role', 'list');

		return {
			update: (new_params) => {
				// Update the stored parameters
				this.list_params = new_params;

				// Handle class changes if needed
				const new_list_class = new_params.list_class || LIST_CLASS_DEFAULT;
				const old_list_class = params.list_class || LIST_CLASS_DEFAULT;

				if (new_list_class !== old_list_class) {
					node.classList.remove(old_list_class);
					node.classList.add(new_list_class);
				}
			},
			destroy: () => {
				// Clean up event handlers
				this.#cleanup_events();

				// Remove the list class
				const old_list_class = params.list_class || LIST_CLASS_DEFAULT;
				node.classList.remove(old_list_class);

				// Remove accessibility attribute
				node.removeAttribute('role');

				// Reset state
				this.list_node = null;
				this.list_params = null;
				this.dragged_element = null;
				this.source_index = -1;
				this.reordering_in_progress = false;
				this.clear_indicators();
			},
		};
	};

	/**
	 * Action for reorderable items - using event delegation, no individual event listeners needed
	 */
	item: Action<HTMLElement, Reorderable_Item_Params> = (node, params) => {
		// Get the current index
		let {index} = params;

		// Store the item with its index in the WeakMap
		this.items.set(node, index);

		// Add the item class
		node.classList.add(this.item_class);

		// Add accessibility attribute
		node.setAttribute('role', 'listitem');

		// Make the item draggable
		node.setAttribute('draggable', 'true');

		return {
			update: (new_params) => {
				// Update the index if it changed
				if (new_params.index !== index) {
					index = new_params.index;
					this.items.set(node, index);
				}
			},
			destroy: () => {
				// With WeakMap, the item will be garbage collected naturally
				// but we still need to clean up classes and attributes

				// Remove classes and attributes
				node.classList.remove(this.item_class);
				node.removeAttribute('role');
				node.removeAttribute('draggable');

				// Clear indicators if this was the active element
				if (this.active_indicator_element === node) {
					this.clear_indicators();
				}

				// Clear dragged element if this was it
				if (this.dragged_element === node) {
					this.dragged_element = null;
				}
			},
		};
	};

	/**
	 * Clean up all resources used by this reorderable instance
	 */
	destroy(): void {
		// Clean up events
		this.#cleanup_events();

		// Clear all state
		this.clear_indicators();
		this.source_index = -1;
		this.dragged_element = null;
		this.reordering_in_progress = false;

		// Remove list class and role if list node still exists
		if (this.list_node) {
			const list_class = this.list_params?.list_class || LIST_CLASS_DEFAULT;
			this.list_node.classList.remove(list_class);
			this.list_node.removeAttribute('role');
			this.list_node = null;
		}

		this.list_params = null;
	}
}
