import type {Action} from 'svelte/action';
import {on} from 'svelte/events';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';
import {
	detect_direction,
	get_drop_position,
	calculate_target_index,
	is_reorder_allowed,
	update_styles_excluding_direction,
	validate_target_index,
} from '$lib/reorderable_helpers.js';

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
 * Item metadata for tracking reorderable items
 */
interface Item_Metadata {
	index: number;
	element: HTMLElement;
	list_node: HTMLElement | null; // Track which list this item belongs to (can be null during initialization)
}

/**
 * Information about pending items waiting for list initialization
 */
interface Pending_Item {
	element: HTMLElement;
	index: number;
}

/**
 * Encapsulates drag and drop reordering functionality
 */
export class Reorderable implements Reorderable_Style_Config {
	// Tracking state
	source_index = -1;
	source_list: HTMLElement | null = null;

	// Direction for drag/drop positioning (can be overridden per list)
	direction: Reorderable_Direction;

	// WeakMaps for element to data mappings
	#items: WeakMap<HTMLElement, Item_Metadata> = new WeakMap();
	#list_params: WeakMap<HTMLElement, Reorderable_List_Params> = new WeakMap();
	#cleanup_handlers: WeakMap<HTMLElement, Array<() => void>> = new WeakMap();

	// Regular Maps/Sets for tracking elements
	#lists: Set<HTMLElement> = new Set();
	#lists_to_items: Map<HTMLElement, Set<HTMLElement>> = new Map();

	// Map of parent elements to their pending items
	#pending_items: Map<HTMLElement, Array<Pending_Item>> = new Map();

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
		this.active_indicator_element?.classList.remove(
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
		if (this.source_index !== -1 && this.#get_element_index(element) === this.source_index) {
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
	 * Get the current index of an element from our tracking
	 */
	#get_element_index(element: HTMLElement): number {
		const metadata = this.#items.get(element);
		return metadata ? metadata.index : -1;
	}

	/**
	 * Programmatically move an item from one position to another within a specific list
	 */
	move_item(from_index: number, to_index: number, list_node?: HTMLElement): void {
		if (from_index === to_index) return;

		// If no list is specified, try to use the first available list
		const final_list_node =
			!list_node && this.#lists.size > 0 ? this.#lists.values().next().value : list_node;

		if (!final_list_node) {
			console.warn('Reorderable.move_item() called without a valid list reference.');
			return;
		}

		const params = this.#list_params.get(final_list_node);
		if (params?.onreorder) {
			// Check if reordering is allowed
			if (!is_reorder_allowed(params.can_reorder, from_index, to_index)) return;

			// Trigger the reorder callback
			params.onreorder(from_index, to_index);
		}
	}

	/**
	 * Register a new item with a list
	 */
	#register_item(element: HTMLElement, index: number, list_node: HTMLElement): void {
		// Store item metadata
		this.#items.set(element, {element, index, list_node});

		// Get or create the set of items for this list
		let items = this.#lists_to_items.get(list_node);
		if (!items) {
			items = new Set<HTMLElement>();
			this.#lists_to_items.set(list_node, items);
		}

		// Add this item to the list's item set
		items.add(element);
	}

	/**
	 * Update an item's index
	 */
	#update_item_index(element: HTMLElement, index: number): void {
		const item = this.#items.get(element);
		if (item) {
			item.index = index;
		}
	}

	/**
	 * Find the list node for an element
	 */
	#find_list_node(element: HTMLElement): HTMLElement | null {
		// First check if this element is itself a list
		if (this.#lists.has(element)) {
			return element;
		}

		// Walk up the DOM to find a parent that's a list
		let current: HTMLElement | null = element;
		while (current) {
			// Check if this is a list we're tracking
			if (this.#lists.has(current)) {
				return current;
			}
			// Move up to the parent
			current = current.parentElement;
		}
		return null;
	}

	/**
	 * Try to attach pending items to their list if it's now available
	 */
	#process_pending_items(parent_element: HTMLElement): void {
		// Get all pending items for this parent
		const pending = this.#pending_items.get(parent_element);
		if (!pending || pending.length === 0) return;

		// Try to find a list for each item
		const still_pending: Array<Pending_Item> = [];

		for (const item of pending) {
			// See if we can find a list for this item now
			const list_node = this.#find_list_node(parent_element);

			if (list_node) {
				// List found, register the item properly
				this.#register_item(item.element, item.index, list_node);
			} else {
				// Still can't find a list, keep it pending
				still_pending.push(item);
			}
		}

		// Update the pending items list
		if (still_pending.length === 0) {
			this.#pending_items.delete(parent_element);
		} else {
			this.#pending_items.set(parent_element, still_pending);
		}
	}

	/**
	 * Find an item element from an event within a specific list
	 */
	#find_item_from_event(event: Event): [HTMLElement, Item_Metadata] | null {
		// Get the target element
		const target = event.target as HTMLElement | null;
		if (!target) return null;

		// Check if the target itself is an item
		if (this.#items.has(target)) {
			const item = this.#items.get(target);
			return item ? [target, item] : null;
		}

		// Walk up the DOM to find a parent that's an item
		let current: HTMLElement | null = target;
		while (current) {
			if (this.#items.has(current)) {
				const item = this.#items.get(current);
				return item ? [current, item] : null;
			}
			current = current.parentElement;
		}

		return null;
	}

	/**
	 * Map to track which list a reordering operation is in progress for
	 * to help prevent race conditions with multiple reorderings
	 */
	#reordering_in_progress: Map<HTMLElement, boolean> = new Map();

	/**
	 * Map to track the currently dragged element for each list
	 */
	#dragged_elements: Map<HTMLElement, HTMLElement> = new Map();

	/**
	 * Re-sync indices for all items in a list
	 */
	#sync_list_indices(list_node: HTMLElement): void {
		// Get all items for this list
		const items = this.#lists_to_items.get(list_node);
		if (!items) return;

		// For each item element in the list DOM order, update its index
		const item_elements = Array.from(list_node.querySelectorAll('[role="listitem"]'));
		item_elements.forEach((element, idx) => {
			const itemEl = element as HTMLElement;
			if (items.has(itemEl)) {
				this.#update_item_index(itemEl, idx);
			}
		});
	}

	/**
	 * Set up event handlers for a list using event delegation
	 */
	#setup_list_events(list: HTMLElement): void {
		// Clean up any existing handlers
		this.#cleanup_list_events(list);

		// Use event delegation for dragstart and dragend events
		const cleanup_dragstart = on(
			list,
			'dragstart',
			(e: DragEvent) => {
				if (!e.dataTransfer) return;

				// Find the item element being dragged
				const found = this.#find_item_from_event(e);
				if (!found) return;

				const [element, item] = found;

				// If reordering is in progress, don't start a new drag
				if (this.#reordering_in_progress.get(list)) {
					e.preventDefault();
					return;
				}

				// Clear any existing drag operation
				this.clear_indicators();
				this.source_index = -1;
				this.source_list = null;

				// Set up the new drag operation
				this.source_index = item.index;
				this.source_list = list;

				// Track the dragged element
				this.#dragged_elements.set(list, element);

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
				// Find the currently dragged element for this list
				const dragged_element = this.#dragged_elements.get(list);
				if (!dragged_element) return;

				// Remove dragging style
				dragged_element.classList.remove(this.dragging_class);

				// Reset tracking
				this.#dragged_elements.delete(list);

				// Reset indicators and source tracking
				this.clear_indicators();
				this.source_index = -1;
				this.source_list = null;
			},
			{capture: true},
		);

		// Set up dragover handler
		const cleanup_dragover = on(list, 'dragover', (e: DragEvent) => {
			e.preventDefault();
			if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';

			// If no active drag or reordering in progress, return
			if (this.source_index === -1 || !this.source_list || this.#reordering_in_progress.get(list)) {
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

			const [target_element, item] = found;

			// Safely check if item still has a valid list_node
			if (!item.list_node) {
				this.clear_indicators();
				return;
			}

			// Skip if dragging onto self - always clear indicators
			if (item.index === this.source_index && item.list_node === this.source_list) {
				this.clear_indicators();
				return;
			}

			// Get drop position
			const position = get_drop_position(this.direction, this.source_index, item.index);

			// Calculate target index
			const target_index = calculate_target_index(this.source_index, item.index, position);

			// Get the list's parameters for the can_reorder check
			const list_params = this.#list_params.get(item.list_node);

			// Check if reordering is allowed
			const allowed = is_reorder_allowed(list_params?.can_reorder, this.source_index, target_index);

			// Update indicator
			this.update_indicator(target_element, position, allowed);
		});

		// Set up drop handler
		const cleanup_drop = on(list, 'drop', (e: DragEvent): void => {
			e.preventDefault();

			// Save current state to local variables to avoid race conditions
			const current_source_index = this.source_index;
			const current_source_list = this.source_list;

			// If no active drag or reordering in progress, return
			if (
				current_source_index === -1 ||
				!current_source_list ||
				this.#reordering_in_progress.get(list)
			) {
				this.clear_indicators();
				return;
			}

			// Find the drop target item
			const found = this.#find_item_from_event(e);
			if (!found) {
				this.clear_indicators();
				this.source_index = -1;
				this.source_list = null;
				return;
			}

			const [_target_element, item] = found;

			// Safety check - ensure list_node still exists
			if (!item.list_node) {
				this.clear_indicators();
				this.source_index = -1;
				this.source_list = null;
				return;
			}

			// Skip if dropping on self
			if (item.list_node === current_source_list && item.index === current_source_index) {
				this.clear_indicators();
				this.source_index = -1;
				this.source_list = null;
				return;
			}

			// Get drop position
			const position = get_drop_position(this.direction, current_source_index, item.index);

			// Calculate target index
			let target_index = calculate_target_index(current_source_index, item.index, position);

			// Get the items for this list
			const items_set = this.#lists_to_items.get(item.list_node);
			const max_index = items_set ? items_set.size - 1 : 0;

			// Validate target index
			target_index = validate_target_index(target_index, max_index);

			// Get the list's parameters for callbacks
			const list_params = this.#list_params.get(item.list_node);

			// Check if reordering is allowed
			if (!is_reorder_allowed(list_params?.can_reorder, current_source_index, target_index)) {
				this.clear_indicators();
				this.source_index = -1;
				this.source_list = null;
				return;
			}

			// Clear state BEFORE performing the reorder
			this.clear_indicators();
			this.source_index = -1;
			this.source_list = null;

			// Mark this list as in the process of reordering
			this.#reordering_in_progress.set(list, true);

			// Store the indices for the callback
			const final_source_index = current_source_index;
			const final_target_index = target_index;

			try {
				// Perform the reordering using the list's callback
				list_params?.onreorder(final_source_index, final_target_index);

				// Sync indices after reordering completes
				setTimeout(() => {
					if (item.list_node) {
						this.#sync_list_indices(item.list_node);
					}
					this.#reordering_in_progress.set(list, false);
				}, 0);
			} catch (error) {
				console.error('Error during reordering:', error);
				this.#reordering_in_progress.set(list, false);
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
		this.#cleanup_handlers.set(list, [
			cleanup_dragstart,
			cleanup_dragend,
			cleanup_dragover,
			cleanup_drop,
			cleanup_dragleave,
		]);
	}

	/**
	 * Clean up event handlers for a list
	 */
	#cleanup_list_events(list: HTMLElement): void {
		// Get the cleanup functions for this list
		const cleanups = this.#cleanup_handlers.get(list);
		if (cleanups) {
			// Call all cleanup functions
			cleanups.forEach((cleanup) => cleanup());
			// Remove from the map
			this.#cleanup_handlers.delete(list);
		}
	}

	/**
	 * Action for the list container
	 */
	list: Action<HTMLElement, Reorderable_List_Params> = (node, params) => {
		// Update direction based on the list's layout if not set
		this.direction = detect_direction(node);

		// Store the list params
		this.#list_params.set(node, params);

		// Track this list
		this.#lists.add(node);

		// Initialize tracking maps
		this.#lists_to_items.set(node, new Set<HTMLElement>());
		this.#reordering_in_progress.set(node, false);

		// Set up event handlers
		this.#setup_list_events(node);

		// Add the list class
		const list_class = params.list_class || LIST_CLASS_DEFAULT;
		node.classList.add(list_class);

		// Add accessibility attribute
		node.setAttribute('role', 'list');

		// Process any pending items
		this.#process_pending_items(node);

		// Process any items that might be waiting for a list in other parents
		for (const parent of this.#pending_items.keys()) {
			if (parent !== node) {
				this.#process_pending_items(parent);
			}
		}

		return {
			update: (new_params) => {
				// Update the stored parameters
				this.#list_params.set(node, new_params);

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
				this.#cleanup_list_events(node);

				// Remove the list class
				const old_list_class = params.list_class || LIST_CLASS_DEFAULT;
				node.classList.remove(old_list_class);

				// Remove accessibility attribute
				node.removeAttribute('role');

				// Clean up the items for this list
				const items = this.#lists_to_items.get(node);
				if (items) {
					// Remove all items from the items map
					items.forEach((item) => {
						this.#items.delete(item);
					});
					// Clear the items set
					items.clear();
				}

				// Remove the list from all tracking maps
				this.#lists.delete(node);
				this.#lists_to_items.delete(node);
				this.#list_params.delete(node);
				this.#reordering_in_progress.delete(node);
				this.#dragged_elements.delete(node);
			},
		};
	};

	/**
	 * Action for reorderable items - using event delegation, no individual event listeners needed
	 */
	item: Action<HTMLElement, Reorderable_Item_Params> = (node, params) => {
		// Get the current index
		let {index} = params;

		// Get the parent element
		const parent_element = node.parentElement;
		if (!parent_element) {
			throw new Error('reorderable item must have a parent element');
		}

		// Try to find the parent list element
		const list_node = this.#find_list_node(parent_element);

		// Add the item class
		node.classList.add(this.item_class);

		// Add accessibility attribute
		node.setAttribute('role', 'listitem');

		// Make the item draggable
		node.setAttribute('draggable', 'true');

		if (list_node) {
			// List is already initialized, register the item
			this.#register_item(node, index, list_node);
		} else {
			// List is not yet initialized, register as pending
			this.#items.set(node, {element: node, index, list_node: null});

			// Add to pending items for the parent element
			const pending = this.#pending_items.get(parent_element) || [];
			pending.push({
				element: node,
				index,
			});
			this.#pending_items.set(parent_element, pending);
		}

		return {
			update: (new_params) => {
				// Update the index if it changed
				if (new_params.index !== index) {
					index = new_params.index;
					this.#update_item_index(node, index);
				}
			},
			destroy: () => {
				// If we have a list_node, clean up the registration
				const item_meta = this.#items.get(node);
				if (item_meta?.list_node) {
					const items = this.#lists_to_items.get(item_meta.list_node);
					if (items) {
						items.delete(node);
					}

					// If this is the dragged element, clear drag state
					if (this.#dragged_elements.get(item_meta.list_node) === node) {
						this.#dragged_elements.delete(item_meta.list_node);
						if (this.source_list === item_meta.list_node) {
							this.source_index = -1;
							this.source_list = null;
						}
					}
				}

				// Remove from the items map
				this.#items.delete(node);

				// Remove from pending items if it's still there
				const parent_element_during_destroy = node.parentElement;
				if (parent_element_during_destroy) {
					const pending = this.#pending_items.get(parent_element_during_destroy);
					if (pending) {
						const updated = pending.filter((p) => p.element !== node);
						if (updated.length === 0) {
							this.#pending_items.delete(parent_element_during_destroy);
						} else {
							this.#pending_items.set(parent_element_during_destroy, updated);
						}
					}
				}

				// Remove classes and attributes
				node.classList.remove(this.item_class);
				node.removeAttribute('role');
				node.removeAttribute('draggable');

				// Clear indicators if this was the active element
				if (this.active_indicator_element === node) {
					this.clear_indicators();
				}
			},
		};
	};

	/**
	 * Clean up all resources used by this reorderable instance
	 */
	destroy(): void {
		// Clean up all lists using regular collection
		for (const list of this.#lists) {
			this.#cleanup_list_events(list);
		}

		// Clear all tracking collections
		this.#lists.clear();
		this.#lists_to_items.clear();
		this.#pending_items.clear();
		this.#dragged_elements.clear();
		this.#reordering_in_progress.clear();

		// Clear all indicators
		this.clear_indicators();

		// Reset state
		this.source_index = -1;
		this.source_list = null;
	}
}
