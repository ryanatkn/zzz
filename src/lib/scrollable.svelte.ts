import type {Action} from 'svelte/action';
import {on} from 'svelte/events';

// TODO BLOCK upstream to Fuz, and see the global `.scrolled` style

export interface Scrollable_Parameters {
	/** CSS class to apply when scrolled. Defaults to 'scrolled'. */
	class_to_add?: string;
	/** Threshold in pixels before considering the element scrolled. Defaults to 0. */
	threshold?: number;
}

/**
 * Class that manages scroll state and provides actions for scroll detection and styling
 */
export class Scrollable {
	/** The current scroll Y position */
	scroll_y: number = $state(0);

	/** Threshold in pixels before considering the element scrolled */
	threshold: number = $state(0);

	/** Whether element is scrolled past threshold */
	scrolled: boolean = $derived(this.scroll_y > this.threshold);

	/** CSS class name to apply when scrolled */
	class_to_add: string = $state('scrolled');

	constructor(params: Scrollable_Parameters = {}) {
		this.class_to_add = params.class_to_add ?? 'scrolled';
		this.threshold = params.threshold ?? 0;
	}

	/**
	 * Action for the scrollable container - detects scrolling and updates state
	 */
	container: Action<Element> = (node) => {
		const onscroll = () => {
			this.scroll_y = node.scrollTop;
		};

		const cleanup = on(node, 'scroll', onscroll);

		// Check initial scroll position
		onscroll();

		return {
			destroy: () => {
				cleanup();
			},
		};
	};

	/**
	 * Action for the element that should receive the scrolled class
	 */
	target: Action<Element> = (node) => {
		if (this.scrolled) {
			node.classList.add(this.class_to_add);
		}

		// TODO BLOCK is this orphaned? better pattern without effect?
		$effect(() => {
			if (this.scrolled) {
				node.classList.add(this.class_to_add);
			} else {
				node.classList.remove(this.class_to_add);
			}
		});

		return {
			destroy: () => {
				node.classList.remove(this.class_to_add);
			},
		};
	};

	/**
	 * Updates the parameters of the scrolled instance
	 */
	update(params: Scrollable_Parameters = {}): void {
		if (params.class_to_add !== undefined) {
			this.class_to_add = params.class_to_add;
		}
		if (params.threshold !== undefined) {
			this.threshold = params.threshold;
		}
	}
}
