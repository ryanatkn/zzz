import {BROWSER} from 'esm-env';

export interface Poller_Options {
	/** Function to call on each poll interval. */
	poll_fn: () => void | Promise<void>;
	/** Polling interval in milliseconds. */
	interval?: number;
	/** Whether to run the poll function immediately on start, defaults to true. */
	immediate?: boolean;
}

/**
 * Helper class to manage polling intervals.
 * Automatically cleans up on disposal.
 */
export class Poller {
	#active: boolean = $state(false);

	/**
	 * Check if the poller is currently active.
	 */
	get active(): boolean {
		return this.#active;
	}

	#timer_id: NodeJS.Timeout | null = null;

	#poll_fn: () => void | Promise<void>;
	#interval: number;
	#immediate: boolean;

	constructor(options: Poller_Options) {
		this.#poll_fn = options.poll_fn;
		this.#interval = options.interval ?? 10_000;
		this.#immediate = options.immediate ?? true;
	}

	/**
	 * Start polling.
	 */
	start(): void {
		if (!BROWSER || this.#active) return;

		this.#active = true;

		// Run immediately if configured
		if (this.#immediate) {
			this.#execute_poll();
		}

		// Set up interval
		this.#timer_id = setInterval(() => {
			this.#execute_poll();
		}, this.#interval);
	}

	/**
	 * Stop polling.
	 */
	stop(): void {
		if (!BROWSER || !this.#active) return;

		this.#active = false;

		if (this.#timer_id) {
			clearInterval(this.#timer_id);
			this.#timer_id = null;
		}
	}

	/**
	 * Update the polling interval. If polling is active, it will restart with the new interval.
	 * No-op if the interval is already set to the same value.
	 */
	set_interval(interval: number | undefined): void {
		if (interval === undefined || this.#interval === interval) return;

		this.#interval = interval;

		if (this.#active) {
			this.stop();
			this.start();
		}
	}

	/**
	 * Dispose of the poller, stopping any active polling.
	 */
	dispose(): void {
		this.stop();
	}

	#execute_poll(): void {
		if (!this.#active) return;

		try {
			const result = this.#poll_fn();
			if (result instanceof Promise) {
				result.catch((error) => {
					this.#handle_error(error);
				});
			}
		} catch (error) {
			this.#handle_error(error);
		}
	}

	/** Doesn't re-throw, users must handle their own errors. */
	#handle_error(error: unknown): void {
		console.error('[poller] poll function error:', error);
	}
}
