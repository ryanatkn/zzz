// @slop Claude Opus 4

import type {Attachment} from 'svelte/attachments';
import {on} from 'svelte/events';
import type {Flavored} from '@ryanatkn/belt/types.js';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';

import {
	detect_reorderable_direction,
	get_reorderable_drop_position,
	calculate_reorderable_target_index,
	is_reorder_allowed,
	validate_reorderable_target_index,
	set_reorderable_drag_data_transfer,
} from '$lib/reorderable_helpers.js';
import {create_client_id} from '$lib/helpers.js';

// TODO BLOCK this breaks styles for elements that are hovered while dragging another element,
// can we make the element modifications less intrusive?

export type Reorderable_Id = Flavored<string, 'Reorderable_Id'>;
export type Reorderable_Item_Id = Flavored<string, 'Reorderable_Item_Id'>;

export type Reorderable_Direction = 'horizontal' | 'vertical';

/**
 * Drop positions on the box model.
 */
export type Reorderable_Drop_Position = 'none' | 'top' | 'bottom' | 'left' | 'right';

/**
 * Valid drop positions, excluding 'none'.
 */
export type Reorderable_Valid_Drop_Position = Exclude<Reorderable_Drop_Position, 'none'>;

/**
 * Styling configuration for reorderable components.
 */
export interface Reorderable_Style_Config {
	list_class: string | null;
	item_class: string | null;
	dragging_class: string | null;
	drag_over_class: string | null;
	drag_over_top_class: string | null;
	drag_over_bottom_class: string | null;
	drag_over_left_class: string | null;
	drag_over_right_class: string | null;
	invalid_drop_class: string | null;
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
 * Parameters for list attachment.
 */
export interface Reorderable_List_Params {
	onreorder: (from_index: number, to_index: number) => void;
	can_reorder?: (from_index: number, to_index: number) => boolean;
	direction?: Reorderable_Direction;
}

/**
 * Parameters for item attachment.
 */
export interface Reorderable_Item_Params {
	index: number;
}

/**
 * Additional configuration options for Reorderable.
 */
export interface Reorderable_Options {
	/**
	 * Forces a specific direction for the reorderable list.
	 * Defaults to auto-detection, `'vertical'` as the fallback.
	 */
	direction?: Reorderable_Direction;
	list_class?: string | null;
	item_class?: string | null;
	dragging_class?: string | null;
	drag_over_class?: string | null;
	drag_over_top_class?: string | null;
	drag_over_bottom_class?: string | null;
	drag_over_left_class?: string | null;
	drag_over_right_class?: string | null;
	invalid_drop_class?: string | null;
}

export class Reorderable implements Reorderable_Style_Config {
	initialized = false;

	// Drag state tracking
	source_index = -1;
	source_item_id: Reorderable_Item_Id | null = null;

	// Indicator state tracking
	active_indicator_item_id: Reorderable_Item_Id | null = null;
	current_indicator: Reorderable_Drop_Position = 'none';

	// Direction for drag/drop positioning
	direction: Reorderable_Direction = 'vertical';

	// Unique identifier for this reorderable instance
	readonly id: Reorderable_Id = `r${create_client_id()}`;

	// Styling configuration
	readonly list_class: string | null;
	readonly item_class: string | null;
	readonly dragging_class: string | null;
	readonly drag_over_class: string | null;
	readonly drag_over_top_class: string | null;
	readonly drag_over_bottom_class: string | null;
	readonly drag_over_left_class: string | null;
	readonly drag_over_right_class: string | null;
	readonly invalid_drop_class: string | null;

	get classes(): Array<string> {
		return [
			this.list_class,
			this.item_class,
			this.dragging_class,
			this.drag_over_class,
			this.drag_over_top_class,
			this.drag_over_bottom_class,
			this.drag_over_left_class,
			this.drag_over_right_class,
			this.invalid_drop_class,
		].filter((c): c is string => c !== null);
	}

	// List reference
	list_node: HTMLElement | null = null;
	list_params: Reorderable_List_Params | null = null;

	// Store both indices and DOM elements by item id
	readonly indices: Map<Reorderable_Item_Id, number> = new Map();
	readonly elements: Map<Reorderable_Item_Id, HTMLElement> = new Map();

	// Single cleanup function for all event handlers
	#cleanup: (() => void) | null = null;

	// Track pending initialization
	#pending_init_frame: number | null = null;

	// Items waiting to be added
	pending_items: Array<{
		id: Reorderable_Item_Id;
		index: number;
		element: HTMLElement;
	}> = [];

	/**
	 * Create a new Reorderable instance.
	 */
	constructor(options: Reorderable_Options = EMPTY_OBJECT) {
		const {
			// preserve nulls
			list_class = LIST_CLASS_DEFAULT,
			item_class = ITEM_CLASS_DEFAULT,
			dragging_class = DRAGGING_CLASS_DEFAULT,
			drag_over_class = DRAG_OVER_CLASS_DEFAULT,
			drag_over_top_class = DRAG_OVER_TOP_CLASS_DEFAULT,
			drag_over_bottom_class = DRAG_OVER_BOTTOM_CLASS_DEFAULT,
			drag_over_left_class = DRAG_OVER_LEFT_CLASS_DEFAULT,
			drag_over_right_class = DRAG_OVER_RIGHT_CLASS_DEFAULT,
			invalid_drop_class = INVALID_DROP_CLASS_DEFAULT,
			direction,
		} = options;

		this.list_class = list_class;
		this.item_class = item_class;
		this.dragging_class = dragging_class;
		this.drag_over_class = drag_over_class;
		this.drag_over_top_class = drag_over_top_class;
		this.drag_over_bottom_class = drag_over_bottom_class;
		this.drag_over_left_class = drag_over_left_class;
		this.drag_over_right_class = drag_over_right_class;
		this.invalid_drop_class = invalid_drop_class;
		if (direction) this.direction = direction;
	}

	/**
	 * Initialize the reorderable component.
	 * Made public for testing purposes.
	 */
	init(): void {
		if (!this.list_node || this.initialized) return;

		// Process any pending items
		for (const {id, index, element} of this.pending_items) {
			this.indices.set(id, index);
			this.elements.set(id, element);
		}
		this.pending_items = [];

		// Set up events
		this.#setup_list_events(this.list_node);

		// Mark as initialized
		this.initialized = true;
	}

	/**
	 * Reset all drag state in one place.
	 */
	#reset_drag_state(): void {
		// Remove dragging class from source element
		if (this.source_item_id && this.dragging_class) {
			const element = this.elements.get(this.source_item_id);
			if (element) {
				element.classList.remove(this.dragging_class);
			}
		}

		// Clear all state
		this.source_item_id = null;
		this.source_index = -1;
		this.clear_indicators();
	}

	/**
	 * Check if a drag operation is valid.
	 */
	get #is_valid_drag_operation(): boolean {
		return this.source_index !== -1 && this.source_item_id !== null;
	}

	/**
	 * Efficiently clear only the active element's indicators.
	 */
	clear_indicators(): void {
		if (!this.active_indicator_item_id) return;

		const element = this.elements.get(this.active_indicator_item_id);
		if (element) {
			element.classList.remove(...this.classes);
		}

		this.active_indicator_item_id = null;
		this.current_indicator = 'none';
	}

	/**
	 * Update indicator on an element by id.
	 */
	update_indicator(
		item_id: Reorderable_Item_Id,
		new_indicator: Reorderable_Drop_Position,
		is_valid = true,
	): void {
		// When hovering over the source element, always clear indicators
		if (this.source_item_id === item_id || new_indicator === 'none') {
			this.clear_indicators();
			return;
		}

		// No change, skip update
		if (item_id === this.active_indicator_item_id && new_indicator === this.current_indicator) {
			return;
		}

		// Get the element
		const element = this.elements.get(item_id);
		if (!element) return;

		// Clear existing indicator
		this.clear_indicators();

		// Apply new indicator classes
		if (this.drag_over_class) element.classList.add(this.drag_over_class);

		if (!is_valid) {
			// Invalid drop
			if (this.invalid_drop_class) element.classList.add(this.invalid_drop_class);
		} else {
			// Valid drop - add direction class
			const direction_class = {
				top: this.drag_over_top_class,
				bottom: this.drag_over_bottom_class,
				left: this.drag_over_left_class,
				right: this.drag_over_right_class,
			}[new_indicator];

			if (direction_class) element.classList.add(direction_class);
		}

		// Update state
		this.active_indicator_item_id = item_id;
		this.current_indicator = new_indicator;
	}

	/**
	 * Find an item from an event target by traversing the DOM.
	 */
	#find_item_from_event(event: Event): [Reorderable_Item_Id, number, HTMLElement] | null {
		const target = event.target as HTMLElement | null;
		if (!target || !this.list_node) return null;

		// Walk up the DOM to find the item element
		let current: HTMLElement | null = target;
		while (current && current !== this.list_node) {
			// Check if this element has a reorderable_item_id data attribute
			const item_id = current.dataset.reorderable_item_id as Reorderable_Item_Id | undefined;
			if (item_id) {
				const index = this.indices.get(item_id);
				const element = this.elements.get(item_id);
				if (index !== undefined && element) {
					return [item_id, index, element];
				}
			}

			// Try next parent
			current = current.parentElement;
		}

		return null;
	}

	/**
	 * Set up event handlers for the list.
	 */
	#setup_list_events(list: HTMLElement): void {
		// Clean up any existing handlers
		this.#cleanup_events();

		const handlers = [
			on(
				list,
				'dragstart',
				(e: DragEvent) => {
					if (!e.dataTransfer) return;

					// Find the item being dragged
					const found = this.#find_item_from_event(e);
					if (!found) return;

					const [item_id, index, element] = found;

					// Set up the drag operation
					this.source_index = index;
					this.source_item_id = item_id;

					// Add dragging style
					if (this.dragging_class) element.classList.add(this.dragging_class);

					// Set up drag data
					set_reorderable_drag_data_transfer(e.dataTransfer, item_id);
				},
				{capture: true},
			),
			on(
				list,
				'dragend',
				() => {
					this.#reset_drag_state();
				},
				{capture: true},
			),
			on(list, 'dragover', (e: DragEvent) => {
				e.preventDefault();
				if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';

				// If no valid drag operation, return
				if (!this.#is_valid_drag_operation) {
					this.clear_indicators();
					return;
				}

				// Find the item being dragged over
				const found = this.#find_item_from_event(e);
				if (!found) {
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
			on(list, 'drop', (e: DragEvent) => {
				e.preventDefault();

				// If no valid drag operation, return
				if (!this.#is_valid_drag_operation) {
					this.#reset_drag_state();
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
					this.source_index,
					item_index,
				);

				// Calculate and validate target index
				let target_index = calculate_reorderable_target_index(
					this.source_index,
					item_index,
					position,
				);
				target_index = validate_reorderable_target_index(target_index, this.indices.size - 1);

				// Check if reordering is allowed
				if (!is_reorder_allowed(this.list_params?.can_reorder, this.source_index, target_index)) {
					this.#reset_drag_state();
					return;
				}

				// Save source index before resetting
				const source_index = this.source_index;

				// Reset state before performing the reorder
				this.#reset_drag_state();

				try {
					// Perform the reordering
					this.list_params?.onreorder(source_index, target_index);
				} catch (error) {
					console.error('Error during reordering:', error);
				}
			}),
			on(list, 'dragleave', (e: DragEvent) => {
				const related_target = e.relatedTarget as Node | null;
				if (!related_target || !list.contains(related_target)) {
					this.clear_indicators();
				}
			}),
			on(list, 'dragenter', (e: DragEvent) => {
				e.preventDefault();
				if (e.dataTransfer) {
					e.dataTransfer.dropEffect = 'move';
				}
			}),
		];

		// Store cleanup function
		this.#cleanup = () => {
			for (const cleanup of handlers) {
				cleanup();
			}
		};
	}

	/**
	 * Clean up event handlers and pending initialization.
	 */
	#cleanup_events(): void {
		if (this.#cleanup) {
			this.#cleanup();
			this.#cleanup = null;
		}

		// Cancel any pending initialization
		if (this.#pending_init_frame !== null) {
			cancelAnimationFrame(this.#pending_init_frame);
			this.#pending_init_frame = null;
		}
	}

	/**
	 * Attachment factory for the list container.
	 */
	list = (params: Reorderable_List_Params): Attachment<HTMLElement> => {
		// TODO any setup here?
		return (node) => {
			// Check if we already have a list node
			if (this.list_node && this.list_node !== node) {
				throw new Error('reorderable instance is already attached to a different list element');
			}

			// Clean up previous state if this is a re-initialization
			if (this.list_node === node) {
				this.#cleanup_events();
				this.initialized = false;
			}

			// Set direction - use provided direction or detect from DOM
			if (params.direction) {
				this.direction = params.direction;
			} else if (!this.initialized) {
				// Only detect on first initialization
				this.direction = detect_reorderable_direction(node);
			}

			// Store the list params and node
			this.list_params = params;
			this.list_node = node;

			// Reset all state
			this.indices.clear();
			this.elements.clear();
			this.#reset_drag_state();

			// Add the list class and identifier
			if (this.list_class) node.classList.add(this.list_class);
			node.setAttribute('role', 'list');
			node.dataset.reorderable_list_id = this.id;

			// Use requestAnimationFrame for initialization - allows all items to register first
			// because the order isn't always guaranteed
			this.#pending_init_frame = requestAnimationFrame(() => {
				this.#pending_init_frame = null;
				this.init();
			});

			return () => {
				// Clean up event handlers
				this.#cleanup_events();

				// Remove the list class and data attribute
				if (this.list_class) node.classList.remove(this.list_class);
				node.removeAttribute('role');
				delete node.dataset.reorderable_list_id;

				// Reset state
				this.list_node = null;
				this.list_params = null;
				this.initialized = false;
				this.pending_items = [];
				this.indices.clear();
				this.elements.clear();
				this.#reset_drag_state();
			};
		};
	};

	/**
	 * Attachment factory for reorderable items.
	 */
	item = (params: Reorderable_Item_Params): Attachment<HTMLElement> => {
		// TODO any setup here?
		return (node) => {
			// Get the current index
			const {index} = params;

			// Generate a unique item id if not already present
			let item_id = node.dataset.reorderable_item_id as Reorderable_Item_Id | undefined;
			if (!item_id) {
				item_id = `i${create_client_id()}`;
				node.dataset.reorderable_item_id = item_id;
			}
			node.setAttribute('draggable', 'true');
			if (this.item_class) node.classList.add(this.item_class);
			node.setAttribute('role', 'listitem');
			node.dataset.reorderable_list_id = this.id;

			if (this.initialized) {
				// If already initialized, add directly to maps
				this.indices.set(item_id, index);
				this.elements.set(item_id, node);
			} else {
				// Otherwise, add to pending items to be processed during initialization
				this.pending_items.push({id: item_id, index, element: node});
			}

			return () => {
				// Remove from appropriate storage
				if (this.initialized) {
					this.indices.delete(item_id);
					this.elements.delete(item_id);
				} else {
					this.pending_items = this.pending_items.filter((item) => item.id !== item_id);
				}

				// Remove classes and attributes
				if (this.item_class) node.classList.remove(this.item_class);
				node.removeAttribute('role');
				node.removeAttribute('draggable');
				delete node.dataset.reorderable_list_id;
				delete node.dataset.reorderable_item_id;

				// Clean up indicator state if needed
				if (this.active_indicator_item_id === item_id) {
					this.active_indicator_item_id = null;
					this.current_indicator = 'none';
				}

				// Clean up source item state if needed
				if (this.source_item_id === item_id) {
					this.#reset_drag_state();
				}
			};
		};
	};
}
