// @slop Claude Sonnet 3.7

import type {Action} from 'svelte/action';
import {on} from 'svelte/events';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';
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
 * Parameters for list action.
 */
export interface Reorderable_List_Params {
	onreorder: (from_index: number, to_index: number) => void;
	can_reorder?: (from_index: number, to_index: number) => boolean;
	direction?: Reorderable_Direction;
}

/**
 * Parameters for item action.
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
	initialized = $state(false);

	// Drag state tracking
	source_index = $state(-1);
	source_item_id: Reorderable_Item_Id | null = $state(null);
	reordering_in_progress = $state(false);

	// Indicator state tracking
	active_indicator_item_id: Reorderable_Item_Id | null = $state(null);
	current_indicator: Reorderable_Drop_Position = $state('none');

	// Direction for drag/drop positioning - initialized either in the constructor or list action
	direction: Reorderable_Direction = $state()!;

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

	readonly classes = $derived.by(() => {
		const c = [];
		if (this.list_class) c.push(this.list_class);
		if (this.item_class) c.push(this.item_class);
		if (this.dragging_class) c.push(this.dragging_class);
		if (this.drag_over_class) c.push(this.drag_over_class);
		if (this.drag_over_top_class) c.push(this.drag_over_top_class);
		if (this.drag_over_bottom_class) c.push(this.drag_over_bottom_class);
		if (this.drag_over_left_class) c.push(this.drag_over_left_class);
		if (this.drag_over_right_class) c.push(this.drag_over_right_class);
		if (this.invalid_drop_class) c.push(this.invalid_drop_class);
		return c;
	});

	// List reference
	list_node: HTMLElement | null = null;
	list_params: Reorderable_List_Params | null = null;

	// Store both indices and DOM elements by item id
	readonly indices: Map<Reorderable_Item_Id, number> = new Map();
	readonly elements: Map<Reorderable_Item_Id, HTMLElement> = new Map();

	cleanup_handlers: Array<() => void> = [];

	// Pending items collection
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
	 * Process any pending items that were registered before the list was initialized.
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
	 * Reset all drag state in one place.
	 */
	#reset_drag_state(): void {
		if (this.source_item_id) {
			if (this.dragging_class) {
				const element = this.elements.get(this.source_item_id);
				if (element) {
					element.classList.remove(this.dragging_class);
				}
			}
			this.source_item_id = null;
		}
		this.clear_indicators();
		this.source_index = -1;
	}

	// TODO better way to do this?
	/**
	 * Meant for testing only.
	 */
	dangerously_reset_drag_state(): void {
		this.#reset_drag_state();
	}

	/**
	 * Check if a drag operation is valid.
	 */
	#is_valid_drag_operation(): boolean {
		return this.source_index !== -1 && this.source_item_id !== null && !this.reordering_in_progress;
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
			if (this.drag_over_class) element.classList.add(this.drag_over_class);

			// Add invalid drop class if needed
			if (!is_valid) {
				if (this.invalid_drop_class) element.classList.add(this.invalid_drop_class);
				this.active_indicator_item_id = item_id;
				this.current_indicator = new_indicator;
				return;
			}

			// Add specific direction class
			switch (new_indicator) {
				case 'top':
					if (this.drag_over_top_class) element.classList.add(this.drag_over_top_class);
					break;
				case 'bottom':
					if (this.drag_over_bottom_class) element.classList.add(this.drag_over_bottom_class);
					break;
				case 'left':
					if (this.drag_over_left_class) element.classList.add(this.drag_over_left_class);
					break;
				case 'right':
					if (this.drag_over_right_class) element.classList.add(this.drag_over_right_class);
					break;
				default:
					throw new Unreachable_Error(new_indicator);
			}

			// Update the active element id
			this.active_indicator_item_id = item_id;
			this.current_indicator = new_indicator;
		}
	}

	/**
	 * Find an item from an event target by traversing the DOM and
	 * looking for a match in our maps.
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
	 * Set up event handlers for the list.
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
					if (this.dragging_class) element.classList.add(this.dragging_class);

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
	 * Clean up event handlers.
	 */
	#cleanup_events(): void {
		for (const cleanup of this.cleanup_handlers) {
			cleanup();
		}
		this.cleanup_handlers = [];
	}

	/**
	 * Action for the list container.
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
		if (params.direction) {
			this.direction = params.direction;
			// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
		} else if (!this.direction) {
			this.direction = detect_reorderable_direction(node);
		}

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
		if (this.list_class) node.classList.add(this.list_class);
		node.setAttribute('role', 'list');
		node.dataset.reorderableListId = this.id;

		// Use requestAnimationFrame for initialization - allows all items to register first
		// because the order isn't always guaranteed
		requestAnimationFrame(() => this.#init());

		return {
			update: (new_params) => {
				// Update the stored parameters
				this.list_params = new_params;
				if (new_params.direction) {
					this.direction = new_params.direction;
				}
			},
			destroy: () => {
				// Clean up event handlers
				this.#cleanup_events();

				// Remove the list class and data attribute
				if (this.list_class) node.classList.remove(this.list_class);
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
	 * Action for reorderable items.
	 */
	item: Action<HTMLElement, Reorderable_Item_Params> = (node, params) => {
		// Get the current index
		let {index} = params;

		// Generate a unique item id if not already present
		let item_id = node.dataset.reorderableItemId as Reorderable_Item_Id | undefined;
		if (!item_id) {
			item_id = `i${create_client_id()}`;
			node.dataset.reorderableItemId = item_id;
		}

		node.setAttribute('draggable', 'true');
		if (this.item_class) node.classList.add(this.item_class);
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
				if (this.dragging_class) node.classList.add(this.dragging_class);

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
				if (this.item_class) node.classList.remove(this.item_class);
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
	 * Update styling configuration.
	 */
	update_styles(styles: Partial<Reorderable_Style_Config>): void {
		for (const key in styles) {
			const value = (styles as any)[key];
			if (value === undefined) continue;
			(this as any)[key] = value;
		}
	}
}
