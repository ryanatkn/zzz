import type {Action} from 'svelte/action';
import {on} from 'svelte/events';

// TODO upstream to Fuz, and see the global `.scrolled` style

// TODO maybe make this more generic than just always adding a class?

export interface Scrollable_Parameters {
	/** CSS class to apply to the target element when scrolled. Defaults to 'scrolled'. */
	target_class?: string;
	/** Threshold in pixels before considering the element scrolled. Defaults to 0. */
	threshold?: number;
}

/**
 * Manages scroll state and provides actions for scroll detection and styling.
 */
export class Scrollable {
	/** CSS class name to apply when scrolled. */
	target_class: string = $state()!;

	/** Threshold in pixels before considering the element scrolled. */
	threshold: number = $state()!;

	/** The current scroll Y position. */
	scroll_y: number = $state(0);

	/** Whether element is scrolled past threshold. */
	readonly scrolled: boolean = $derived(this.scroll_y > this.threshold);

	constructor(params?: Scrollable_Parameters) {
		this.target_class = params?.target_class ?? 'scrolled';
		this.threshold = params?.threshold ?? 0;
	}

	/**
	 * Action for the scrollable container - detects scrolling and updates state.
	 */
	container: Action<Element> = (element) => {
		const computed_style = window.getComputedStyle(element);

		const onscroll = () => {
			const reversed = computed_style.flexDirection === 'column-reverse';
			this.scroll_y = element.scrollTop * (reversed ? -1 : 1);
		};

		const cleanup = on(element, 'scroll', onscroll);

		onscroll();

		return {
			destroy: () => {
				cleanup();
			},
		};
	};

	/**
	 * Action for the element that should receive the scrolled class.
	 */
	target: Action<Element> = (element) => {
		if (this.scrolled) {
			element.classList.add(this.target_class);
		}

		// TODO better pattern without effect, maybe require a param? but then the state isn't synced
		const cleanup = $effect.root(() => {
			$effect(() => {
				if (this.scrolled) {
					element.classList.add(this.target_class);
				} else {
					element.classList.remove(this.target_class);
				}
			});
		});

		return {
			destroy: () => {
				element.classList.remove(this.target_class);
				cleanup();
			},
		};
	};

	/**
	 * Updates the parameters of the scrolled instance.
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
