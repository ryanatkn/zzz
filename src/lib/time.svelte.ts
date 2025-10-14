import {z} from 'zod';
import {SvelteDate} from 'svelte/reactivity';
import {BROWSER} from 'esm-env';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {
	format_datetime,
	format_short_date,
	format_time,
	format_timestamp,
} from '$lib/time_helpers.js';

export const Time_Json = Cell_Json.extend({}).meta({cell_class_name: 'Time'});
export type Time_Json = z.infer<typeof Time_Json>;
export type Time_Json_Input = z.input<typeof Time_Json>;

/**
 * Options for configuring a Time instance.
 */
export interface Time_Options extends Cell_Options<typeof Time_Json> {
	/**
	 * Interval in milliseconds for updating now.
	 * @default 60_000 (1 minute)
	 */
	interval?: number;

	/**
	 * Whether to automatically start the timer on initialization.
	 * @default true in browser, false otherwise
	 */
	autostart?: boolean;
}

/**
 * Reactive time management class that provides time-related utilities.
 * Has a configurable update interval that defaults to
 * a full minute to minimize wasteful reactivity,
 * so it's suitable for any cases that need at best 1-minute precision, unless reconfigured.
 */
export class Time extends Cell<typeof Time_Json> {
	/**
	 * Default update interval in milliseconds (1 minute).
	 * The idea is to minimize reactivity and CPU usage for a common use case.
	 */
	static DEFAULT_INTERVAL = 60_000;

	/**
	 * Current time that updates on the configured interval.
	 * This is reactive and can be used in derived computations.
	 */
	readonly now: SvelteDate = new SvelteDate();
	readonly now_ms: number = $derived(this.now.getTime());
	readonly now_timestamp = $derived(format_timestamp(this.now));
	readonly now_formatted_short_date: string = $derived(format_short_date(this.now));
	readonly now_formatted_datetime: string = $derived(format_datetime(this.now));
	readonly now_formatted_time: string = $derived(format_time(this.now));

	/**
	 * The interval in milliseconds between time updates.
	 */
	interval: number = $state(Time.DEFAULT_INTERVAL);

	/**
	 * Whether the interval timer is currently running.
	 */
	running: boolean = $state(false);

	#timer?: NodeJS.Timeout;

	constructor(options: Time_Options) {
		// Pass schema and options to base constructor
		super(Time_Json, options);

		// Auto-start based on options or default to browser environment
		const autostart = options.autostart ?? BROWSER;
		if (autostart) {
			this.start();
		}

		// Initialize cell
		this.init();
	}

	/**
	 * Starts the interval timer if it's not already running.
	 */
	start(): boolean {
		if (this.running) return false;

		this.#timer = setInterval(() => {
			this.update_now(Date.now());
		}, this.interval);

		this.running = true;
		return true;
	}

	/**
	 * Stops the interval timer if it's running.
	 */
	stop(): boolean {
		if (!this.running) return false;

		if (this.#timer) {
			clearInterval(this.#timer);
			this.#timer = undefined;
		}

		this.running = false;
		return true;
	}

	/**
	 * Restarts the interval timer with a new interval.
	 */
	restart(interval?: number): void {
		if (interval !== undefined) {
			this.interval = interval;
		}

		this.stop();
		this.start();
	}

	/**
	 * Updates the now to the current time immediately.
	 */
	update_now(value = Date.now()): void {
		this.now.setTime(value);
	}

	/**
	 * Override Cell's destroy method to ensure timer cleanup.
	 */
	destroy(): void {
		this.stop();
	}
}
