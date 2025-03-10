import type {Action} from 'svelte/action';
import type {Snippet} from 'svelte';
import {on} from 'svelte/events';
import {swallow} from '@ryanatkn/belt/dom.js';
import type {TransitionConfig} from 'svelte/transition';

import {type Position, type Alignment, generate_position_styles} from '$lib/position_helpers.js';

/**
 * Parameters for configuring the popover
 */
export interface Popover_Parameters {
	/** Position of the popover relative to its trigger */
	position?: Position;
	/** Alignment along the position edge */
	align?: Alignment;
	/** Distance from the position */
	offset?: string;
	/** Whether to disable closing when clicking outside */
	disable_outside_click?: boolean;
	/** Custom class for the popover content */
	popover_class?: string;
	/** Optional callback when popover is shown */
	onshow?: () => void;
	/** Optional callback when popover is hidden */
	onhide?: () => void;
}

/**
 * Parameters for the popover trigger action
 */
export interface Popover_Trigger_Parameters extends Popover_Parameters {
	/** Content to render in the popover (as a snippet) */
	content?: Snippet;
}

/**
 * Support both Svelte transitions and custom transitions
 */
export type Transition_Function = (node: HTMLElement) => TransitionConfig | {destroy?: () => void};

/**
 * Parameters for the popover content action
 */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type
export interface Popover_Content_Parameters extends Popover_Parameters {
	// Container reference is now managed internally through the container action
}

/**
 * Class that manages state and provides actions for popovers
 */
export class Popover {
	/** Whether the popover is currently visible */
	visible = $state(false);

	/** Position of the popover relative to its trigger */
	position: Position = $state('bottom');

	/** Alignment along the position edge */
	align: Alignment = $state('center');

	/** Distance from the position */
	offset = $state('0');

	/** Whether to disable closing when clicking outside */
	disable_outside_click = $state(false);

	/** Custom class for the popover */
	popover_class = $state('');

	/** Reference to the trigger element */
	#trigger_element: HTMLElement | null = null;

	/** Reference to the content element */
	#content_element: HTMLElement | null = null;

	/** Reference to the container element */
	#container_element: HTMLElement | null = null;

	/** Onshow callback */
	#onshow: (() => void) | undefined = undefined;

	/** Onhide callback */
	#onhide: (() => void) | undefined = undefined;

	/** Cleanup function for document click handler */
	#document_click_cleanup: (() => void) | undefined = undefined;

	constructor(params?: Popover_Parameters) {
		if (params) {
			this.update(params);
		}
	}

	/**
	 * Sets up or removes the document click handler based on current state
	 */
	#manage_outside_click(): void {
		// If we should have an outside click handler but don't, add one
		if (this.visible && !this.disable_outside_click && !this.#document_click_cleanup) {
			this.#document_click_cleanup = on(document, 'click', (event) => {
				const target = event.target as Node;

				if (
					this.#content_element &&
					this.#trigger_element &&
					!this.#content_element.contains(target) &&
					!this.#trigger_element.contains(target) &&
					(!this.#container_element || !this.#container_element.contains(target))
				) {
					this.hide();
				}
			});
		}
		// If we shouldn't have an outside click handler but do, remove it
		else if ((!this.visible || this.disable_outside_click) && this.#document_click_cleanup) {
			this.#document_click_cleanup();
			this.#document_click_cleanup = undefined;
		}
	}

	/**
	 * Updates the popover configuration
	 */
	update(params: Popover_Parameters): void {
		// Store the old class before updating
		const old_class = this.popover_class;
		const old_disable_outside_click = this.disable_outside_click;

		// Update properties
		if (params.position !== undefined) this.position = params.position;
		if (params.align !== undefined) this.align = params.align;
		if (params.offset !== undefined) this.offset = params.offset;
		if (params.popover_class !== undefined) this.popover_class = params.popover_class;
		if (params.disable_outside_click !== undefined)
			this.disable_outside_click = params.disable_outside_click;

		// Update classes on content element if it exists and class changed
		if (
			this.#content_element &&
			params.popover_class !== undefined &&
			old_class !== params.popover_class
		) {
			// Remove old class if it exists
			if (old_class) {
				this.#content_element.classList.remove(old_class);
			}

			// Add new class if it exists
			if (this.popover_class) {
				this.#content_element.classList.add(this.popover_class);
			}
		}

		// Update outside click handler if disable_outside_click changed
		if (
			params.disable_outside_click !== undefined &&
			old_disable_outside_click !== this.disable_outside_click
		) {
			this.#manage_outside_click();
		}

		if (params.onshow !== undefined) this.#onshow = params.onshow;
		if (params.onhide !== undefined) this.#onhide = params.onhide;

		// Update ARIA attributes on trigger if it exists
		this.#update_trigger_aria_attributes();

		// Note: We don't directly manipulate visibility with style properties
		// to allow Svelte transitions to work properly
	}

	/**
	 * Updates ARIA attributes and state for accessibility
	 * But does NOT directly manipulate visibility styling
	 */
	#update_trigger_aria_attributes(): void {
		if (this.#trigger_element) {
			this.#trigger_element.setAttribute('aria-expanded', this.visible ? 'true' : 'false');

			// If we have a content element, establish the relationship
			if (this.#content_element) {
				const content_id =
					this.#content_element.id || `popover-content-${Math.random().toString(36).slice(2, 11)}`;
				this.#content_element.id = content_id;
				this.#trigger_element.setAttribute('aria-controls', content_id);
			}
		}
	}

	/**
	 * Shows the popover
	 */
	show(): void {
		if (this.visible) return;

		this.visible = true;

		// Set up outside click handler when showing the popover
		this.#manage_outside_click();

		// Update ARIA attributes
		this.#update_trigger_aria_attributes();

		if (this.#onshow) this.#onshow();
	}

	/**
	 * Hides the popover
	 */
	hide(): void {
		if (!this.visible) return;

		this.visible = false;

		// Clean up outside click handler when hiding the popover
		this.#manage_outside_click();

		// Update ARIA attributes
		this.#update_trigger_aria_attributes();

		if (this.#onhide) this.#onhide();
	}

	/**
	 * Toggles the popover visibility
	 */
	toggle(): void {
		if (this.visible) {
			this.hide();
		} else {
			this.show();
		}
	}

	/**
	 * Action for the container element
	 */
	container: Action = (node) => {
		this.#container_element = node;

		return {
			destroy: () => {
				if (this.#container_element === node) {
					this.#container_element = null;
				}
			},
		};
	};

	/**
	 * Action for the trigger element that shows/hides the popover
	 */
	trigger: Action<HTMLElement, Popover_Trigger_Parameters | void> = (node, params) => {
		this.#trigger_element = node;

		// Update instance parameters from action params
		if (params) {
			this.update(params);
		}

		// Initialize ARIA attributes
		this.#update_trigger_aria_attributes();

		const click_handler = on(node, 'click', (e) => {
			swallow(e);
			this.toggle();
		});

		return {
			update: (new_params) => {
				// Update popover parameters reactively when action params change
				if (new_params) {
					this.update(new_params);
				}
			},
			destroy: () => {
				click_handler();
				if (this.#trigger_element === node) {
					this.#trigger_element = null;
				}
			},
		};
	};

	/**
	 * Action for the popover content element
	 */
	content: Action<HTMLElement, Popover_Content_Parameters | void> = (node, params) => {
		this.#content_element = node;

		// Update instance parameters from action params
		if (params) {
			this.update(params);
		}

		// Add classes
		if (this.popover_class) {
			node.classList.add(this.popover_class);
		}

		// Set up position relative to the container (will be absolute)
		node.style.position = 'absolute';

		// Note: We do not set visibility or display styles here
		// to allow Svelte's transitions to work properly

		// Apply position styles based on the target container
		const update_node_position = () => {
			// Generate styles with direct parameters instead of options object
			const styles = generate_position_styles(this.position, this.align, this.offset);

			// Clear all position-related properties first
			// This ensures that properties set previously but not in new styles are removed
			const position_props = [
				'top',
				'bottom',
				'left',
				'right',
				'transform',
				'transform-origin',
				'width',
				'height', // For overlay
			];
			for (const prop of position_props) {
				node.style.removeProperty(prop);
			}

			// Apply new styles
			for (const key in styles) {
				node.style.setProperty(key, styles[key]);
			}
		};

		// Initial position setup and click handler management
		update_node_position();
		this.#manage_outside_click();

		// Set ARIA attributes for accessibility
		if (!node.hasAttribute('role')) {
			node.setAttribute('role', 'dialog');
		}

		return {
			update: (new_params) => {
				// Update popover parameters reactively when action params change
				if (new_params) {
					this.update(new_params);
					update_node_position();
				}
			},
			destroy: () => {
				// Clean up document click handler if it exists
				if (this.#document_click_cleanup) {
					this.#document_click_cleanup();
					this.#document_click_cleanup = undefined;
				}

				// Remove class
				if (this.popover_class) {
					node.classList.remove(this.popover_class);
				}

				// Clear reference
				if (this.#content_element === node) {
					this.#content_element = null;
				}
			},
		};
	};
}
