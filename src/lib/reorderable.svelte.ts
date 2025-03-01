import type {Action} from 'svelte/action';
import {on} from 'svelte/events';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';
import type {Flavored} from '@ryanatkn/belt/types.js';

import {
	detect_reorderable_direction,
	get_reorderable_drop_position,
	calculate_reorderable_target_index,
	is_reorder_allowed,
	validate_reorderable_target_index,
	set_reorderable_drag_data_transfer,
} from '$lib/reorderable_helpers.js';

export type Reorderable_Id = Flavored<string, 'Reorderable_Id'>;
export type Reorderable_Item_Id = Flavored<string, 'Reorderable_Item_Id'>;

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
	list_class: string; // Moved from params to main config
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

export class Reorderable implements Reorderable_Style_Config {
	// List reference
	list_node: HTMLElement | null = null;
	list_params: Reorderable_List_Params | null = null;

	// Store both indices and DOM elements by item ID
	indices: Map<Reorderable_Item_Id, number> = new Map();
	elements: Map<Reorderable_Item_Id, HTMLElement> = new Map();

	cleanup_handlers: Array<() => void> = [];

	// Initialization state
	initialized = false;

	// Drag state tracking
	source_index = -1;
	source_item_id: Reorderable_Item_Id | null = null;
	reordering_in_progress = false;

	// Indicator state tracking
	active_indicator_item_id: Reorderable_Item_Id | null = null;
	current_indicator: Reorderable_Drop_Position = 'none';

	// Direction for drag/drop positioning
	direction: Reorderable_Direction;

	// Unique identifier for this reorderable instance
	readonly id: Reorderable_Id = `r${Math.random().toString(36).substring(2, 8)}`;

	// Styling configuration
	list_class: string;
	item_class: string;
	dragging_class: string;
	drag_over_class: string;
	drag_over_top_class: string;
	drag_over_bottom_class: string;
	drag_over_left_class: string;
	drag_over_right_class: string;
	invalid_drop_class: string;

	// Pending items collection
	pending_items: Array<{
		id: Reorderable_Item_Id;
		index: number;
		element: HTMLElement;
	}> = [];

	/**
	 * Create a new Reorderable instance
	 */
	constructor(options?: Reorderable_Options) {
		// Initialize with defaults
		this.list_class = LIST_CLASS_DEFAULT;
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
	}

	/**
	 * Initialize the reorderable component
	 */
	#init(): void {
		if (!this.list_node) return;

		if (this.initialized) {
			if (!process.env.VITEST) console.error('Reorderable is already initialized'); // TODO better way to silence this?
			return;
		}

		// Process any pending items first - this is crucial
		this.#process_pending_items();

		// Set up events
		this.#setup_list_events(this.list_node);

		// Mark as initialized
		this.initialized = true;
	}

	/**
	 * Process any pending items that were registered before the list was initialized
	 */
	#process_pending_items(): void {
		if (this.pending_items.length === 0) return;

		// Add all pending items to our maps
		for (const {id, index, element} of this.pending_items) {
			this.indices.set(id, index);
			this.elements.set(id, element);
		}

		// Clear the pending items
		this.pending_items = [];
	}

	/**
	 * Reset all drag state in one place
	 */
	#reset_drag_state(): void {
		if (this.source_item_id) {
			const element = this.elements.get(this.source_item_id);
			if (element) {
				element.classList.remove(this.dragging_class);
			}
			this.source_item_id = null;
		}
		this.clear_indicators();
		this.source_index = -1;
	}

	// TODO better way to do this?
	/**
	 * Meant for testing only
	 */
	dangerously_reset_drag_state(): void {
		this.#reset_drag_state();
	}

	/**
	 * Check if a drag operation is valid
	 */
	#is_valid_drag_operation(): boolean {
		return this.source_index !== -1 && this.source_item_id !== null && !this.reordering_in_progress;
	}

	/**
	 * Efficiently clear only the active element's indicators
	 */
	clear_indicators(): void {
		if (!this.active_indicator_item_id) return;

		const element = this.elements.get(this.active_indicator_item_id);
		if (element) {
			element.classList.remove(
				this.drag_over_class,
				this.drag_over_top_class,
				this.drag_over_bottom_class,
				this.drag_over_left_class,
				this.drag_over_right_class,
				this.invalid_drop_class,
			);
		}

		this.active_indicator_item_id = null;
		this.current_indicator = 'none';
	}

	/**
	 * Update indicator on an element by ID
	 */
	update_indicator(
		item_id: Reorderable_Item_Id,
		new_indicator: Reorderable_Drop_Position,
		is_valid = true,
	): void {
		// Get the element from our stored elements
		const element = this.elements.get(item_id);
		if (!element) return;

		// When hovering over the source element, always clear indicators and return
		if (this.source_item_id === item_id) {
			this.clear_indicators();
			return;
		}

		// No change, skip update
		if (item_id === this.active_indicator_item_id && new_indicator === this.current_indicator) {
			return;
		}

		// Clear existing indicator
		this.clear_indicators();

		// Apply new indicator classes if needed
		if (new_indicator !== 'none') {
			element.classList.add(this.drag_over_class);

			// Add invalid drop class if needed
			if (!is_valid) {
				element.classList.add(this.invalid_drop_class);
				this.active_indicator_item_id = item_id;
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

			// Update the active element ID
			this.active_indicator_item_id = item_id;
			this.current_indicator = new_indicator;
		}
	}

	/**
	 * Find an item from an event target by traversing the DOM and
	 * looking for a match in our maps
	 */
	#find_item_from_event(event: Event): [Reorderable_Item_Id, number, HTMLElement] | null {
		const target = event.target as HTMLElement | null;
		if (!target || !this.list_node) return null;

		// Walk up the DOM to find the item element
		let current: HTMLElement | null = target;
		while (current && current !== this.list_node) {
			// Check if this element has a data-reorderable-item-id attribute
			const item_id = current.dataset.reorderableItemId as Reorderable_Item_Id | undefined;
			if (item_id && this.indices.has(item_id)) {
				const index = this.indices.get(item_id);
				if (index === undefined) return null;

				// Double check that the element in our map matches the current element
				const stored_element = this.elements.get(item_id);
				if (
					stored_element &&
					(stored_element === current ||
						stored_element.contains(current) ||
						current.contains(stored_element))
				) {
					return [item_id, index, stored_element];
				}
			}

			// Try next parent
			current = current.parentElement;
		}

		return null;
	}

	/**
	 * Set up event handlers for the list
	 */
	#setup_list_events(list: HTMLElement): void {
		// Clean up any existing handlers
		this.#cleanup_events();

		// The dragstart event is crucial - it sets up the entire drag operation
		this.cleanup_handlers.push(
			on(
				list,
				'dragstart',
				(e: DragEvent) => {
					if (!e.dataTransfer) return;

					// If reordering is in progress, don't start a new drag
					// FIXED: Check this first before doing any other work
					if (this.reordering_in_progress) {
						e.preventDefault();
						return;
					}

					// Find the item being dragged
					const found = this.#find_item_from_event(e);
					if (!found) return;

					const [item_id, index, element] = found;

					// Clear any existing drag operation
					this.clear_indicators();
					this.source_index = -1;
					this.source_item_id = null;

					// Set up the new drag operation
					this.source_index = index;
					this.source_item_id = item_id;

					// Add dragging style
					element.classList.add(this.dragging_class);

					// Set up drag data with the helper function
					set_reorderable_drag_data_transfer(e.dataTransfer, item_id);
				},
				{capture: true},
			),
		);

		this.cleanup_handlers.push(
			on(
				list,
				'dragend',
				(_: DragEvent) => {
					this.#reset_drag_state();
				},
				{capture: true},
			),
		);

		// Set up dragover handler
		this.cleanup_handlers.push(
			on(list, 'dragover', (e: DragEvent) => {
				e.preventDefault();
				if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';

				// If no valid drag operation, return
				if (!this.#is_valid_drag_operation()) {
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

				const [item_id, item_index] = found;

				// Skip if dragging onto self
				if (this.source_item_id === item_id) {
					this.clear_indicators();
					return;
				}

				// Get drop position
				const position = get_reorderable_drop_position(
					this.direction,
					this.source_index,
					item_index,
				);

				// Calculate target index
				const target_index = calculate_reorderable_target_index(
					this.source_index,
					item_index,
					position,
				);

				// Check if reordering is allowed
				const allowed = is_reorder_allowed(
					this.list_params?.can_reorder,
					this.source_index,
					target_index,
				);

				// Update indicator
				this.update_indicator(item_id, position, allowed);
			}),
		);

		// Set up drop handler
		this.cleanup_handlers.push(
			on(list, 'drop', (e: DragEvent): void => {
				e.preventDefault();

				// Save current state to local variables to avoid race conditions
				const current_source_index = this.source_index;

				// If no valid drag operation, return
				if (!this.#is_valid_drag_operation()) {
					this.clear_indicators();
					return;
				}

				// Find the drop target item
				const found = this.#find_item_from_event(e);
				if (!found) {
					this.#reset_drag_state();
					return;
				}

				const [item_id, item_index] = found;

				// Skip if dropping on self
				if (this.source_item_id === item_id) {
					this.#reset_drag_state();
					return;
				}

				// Get drop position
				const position = get_reorderable_drop_position(
					this.direction,
					current_source_index,
					item_index,
				);

				// Calculate target index
				let target_index = calculate_reorderable_target_index(
					current_source_index,
					item_index,
					position,
				);

				// Validate target index
				const max_items_count = this.indices.size;
				target_index = validate_reorderable_target_index(target_index, max_items_count - 1);

				// Check if reordering is allowed
				const allowed = is_reorder_allowed(
					this.list_params?.can_reorder,
					current_source_index,
					target_index,
				);

				if (!allowed) {
					this.#reset_drag_state();
					return;
				}

				// Reset state BEFORE performing the reorder
				this.#reset_drag_state();

				// Mark as in the process of reordering
				this.reordering_in_progress = true;

				try {
					// Perform the reordering using the callback
					this.list_params?.onreorder(current_source_index, target_index);
				} catch (error) {
					console.error('Error during reordering:', error);
				} finally {
					this.reordering_in_progress = false;
				}
			}),
		);

		// Set up dragleave and dragenter handlers
		this.cleanup_handlers.push(
			on(list, 'dragleave', (e: DragEvent) => {
				const related_target = e.relatedTarget as Node | null;
				if (!related_target || !list.contains(related_target)) {
					this.clear_indicators();
				}
			}),
		);

		this.cleanup_handlers.push(
			on(list, 'dragenter', (e: DragEvent) => {
				e.preventDefault();
				if (e.dataTransfer) {
					e.dataTransfer.dropEffect = 'move';
				}
			}),
		);
	}

	/**
	 * Clean up event handlers
	 */
	#cleanup_events(): void {
		for (const cleanup of this.cleanup_handlers) {
			cleanup();
		}
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
			this.initialized = false;
		}

		// Update direction based on the list's layout if not manually set
		this.direction = detect_reorderable_direction(node);

		// Store the list params and node
		this.list_params = params;
		this.list_node = node;

		// Reset all state
		this.indices.clear();
		this.elements.clear();
		this.reordering_in_progress = false;
		this.source_item_id = null;
		this.source_index = -1;

		// Add the list class and identifier
		node.classList.add(this.list_class);
		node.setAttribute('role', 'list');
		node.dataset.reorderableListId = this.id;

		// Use requestAnimationFrame for initialization - allows all items to register first
		// because the order isn't always guaranteed
		requestAnimationFrame(() => this.#init());

		return {
			update: (new_params) => {
				// Update the stored parameters
				this.list_params = new_params;
			},
			destroy: () => {
				// Clean up event handlers
				this.#cleanup_events();

				// Remove the list class and data attribute
				node.classList.remove(this.list_class);
				node.removeAttribute('role');
				delete node.dataset.reorderableListId;

				// Reset state
				this.list_node = null;
				this.list_params = null;
				this.source_item_id = null;
				this.source_index = -1;
				this.reordering_in_progress = false;
				this.clear_indicators();
				this.indices.clear();
				this.elements.clear();
				this.initialized = false;
				this.pending_items = [];
			},
		};
	};

	/**
	 * Action for reorderable items
	 */
	item: Action<HTMLElement, Reorderable_Item_Params> = (node, params) => {
		// Get the current index
		let {index} = params;

		// Generate a unique item ID if not already present
		let item_id = node.dataset.reorderableItemId as Reorderable_Item_Id | undefined;
		if (!item_id) {
			item_id = `i${Math.random().toString(36).substring(2, 10)}` as Reorderable_Item_Id;
			node.dataset.reorderableItemId = item_id;
		}

		// Ensure the node has proper drag-drop attributes
		node.setAttribute('draggable', 'true');
		node.classList.add(this.item_class);
		node.setAttribute('role', 'listitem');
		node.dataset.reorderableListId = this.id;

		if (this.initialized) {
			// If already initialized, add directly to maps
			this.indices.set(item_id, index);
			this.elements.set(item_id, node);
		} else {
			// Otherwise, add to pending items to be processed during initialization
			this.pending_items.push({id: item_id, index, element: node});
		}

		// Add a direct dragstart handler to ensure the drag operation is properly initiated
		// This is crucial for nested components like in Bit_List
		const dragstart_cleanup = on(node, 'dragstart', (e: DragEvent) => {
			if (!e.dataTransfer) return;

			// Only handle if we haven't already set up this drag operation
			if (this.source_index === -1 && this.source_item_id === null) {
				// Set up the drag operation directly
				this.source_index = index;
				this.source_item_id = item_id;

				// Add dragging style
				node.classList.add(this.dragging_class);

				// Set up drag data with the helper function
				set_reorderable_drag_data_transfer(e.dataTransfer, item_id);
			}
		});

		return {
			update: (new_params) => {
				// Update the index if it changed
				if (new_params.index !== index) {
					index = new_params.index;

					// Update in the appropriate storage
					if (this.initialized) {
						this.indices.set(item_id, index);
					} else {
						// Find and update in pending items
						const pending_item = this.pending_items.find((item) => item.id === item_id);
						if (pending_item) {
							pending_item.index = index;
						}
					}
				}
			},
			destroy: () => {
				// Clean up the direct dragstart handler
				dragstart_cleanup();

				// Remove from appropriate storage
				if (this.initialized) {
					this.indices.delete(item_id);
					this.elements.delete(item_id);
				} else {
					this.pending_items = this.pending_items.filter((item) => item.id !== item_id);
				}

				// Remove classes and attributes
				node.classList.remove(this.item_class);
				node.removeAttribute('role');
				node.removeAttribute('draggable');
				delete node.dataset.reorderableListId;
				delete node.dataset.reorderableItemId;

				// Clean up indicator state if needed
				if (this.active_indicator_item_id === item_id) {
					this.active_indicator_item_id = null;
					this.current_indicator = 'none';
				}

				// Clean up source item state if needed
				if (this.source_item_id === item_id) {
					this.source_item_id = null;
					this.source_index = -1;
				}
			},
		};
	};

	/**
	 * Update styling configuration
	 */
	update_styles(styles: Reorderable_Style_Config_Partial): void {
		for (const key in styles) {
			const value = (styles as any)[key];
			if (value === undefined) continue;
			(this as any)[key] = value;
		}
	}
}
