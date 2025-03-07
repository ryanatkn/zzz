import type {Action} from 'svelte/action';
import {on} from 'svelte/events';

// TODO BLOCK upstream to Fuz, and see the global `.scrolled` style

// TODO maybe make this more generic than just always adding a class?

export interface Scrollable_Parameters {
	/** CSS class to apply to the target element when scrolled. Defaults to 'scrolled' */
	target_class?: string;
	/** Threshold in pixels before considering the element scrolled. Defaults to 0 */
	threshold?: number;
}

/**
 * Manages scroll state and provides actions for scroll detection and styling
 */
export class Scrollable {
	/** CSS class name to apply when scrolled */
	target_class: string = $state()!;

	/** Threshold in pixels before considering the element scrolled */
	threshold: number = $state()!;

	/** The current scroll Y position */
	scroll_y: number = $state(0);

	/** Whether element is scrolled past threshold */
	scrolled: boolean = $derived(this.scroll_y > this.threshold);

	constructor(params?: Scrollable_Parameters) {
		this.target_class = params?.target_class ?? 'scrolled';
		this.threshold = params?.threshold ?? 0;
	}

	/**
	 * Action for the scrollable container - detects scrolling and updates state
	 */
	container: Action<Element> = (node) => {
		const onscroll = () => {
			this.scroll_y = node.scrollTop;
		};

		const cleanup = on(node, 'scroll', onscroll);

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
			node.classList.add(this.target_class);
		}

		// TODO is this orphaned? better pattern without effect? if keeping the effect, then correctly removing the previous `target_class` on change
		$effect(() => {
			if (this.scrolled) {
				node.classList.add(this.target_class);
			} else {
				node.classList.remove(this.target_class);
			}
		});

		return {
			destroy: () => {
				node.classList.remove(this.target_class);
			},
		};
	};

	/**
	 * Updates the parameters of the scrolled instance
	 */
	update(params: Scrollable_Parameters): void {
		if (params.target_class !== undefined) {
			this.target_class = params.target_class;
		}
		if (params.threshold !== undefined) {
			this.threshold = params.threshold;
		}
	}
}
