// @slop claude_sonnet_4

// @vitest-environment jsdom

import {test, expect, describe, vi, beforeEach, afterEach} from 'vitest';

import {Poller} from '$lib/poller.svelte.js';

describe('Poller', () => {
	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		vi.restoreAllMocks();
		vi.useRealTimers();
	});

	test('should initialize with correct default values', () => {
		const poll_fn = vi.fn();
		const poller = new Poller({poll_fn});

		expect(poller.active).toBe(false);
	});

	test('should start polling with immediate execution by default', () => {
		const poll_fn = vi.fn();
		const poller = new Poller({poll_fn});

		poller.start();

		expect(poller.active).toBe(true);
		expect(poll_fn).toHaveBeenCalledTimes(1);

		// Advance time to trigger interval
		vi.advanceTimersByTime(Poller.DEFAULT_INTERVAL);
		expect(poll_fn).toHaveBeenCalledTimes(2);
	});

	test('should start polling without immediate execution when configured', () => {
		const poll_fn = vi.fn();
		const poller = new Poller({poll_fn, immediate: false});

		poller.start();

		expect(poller.active).toBe(true);
		expect(poll_fn).not.toHaveBeenCalled();

		// Advance time to trigger interval
		vi.advanceTimersByTime(Poller.DEFAULT_INTERVAL);
		expect(poll_fn).toHaveBeenCalledTimes(1);
	});

	test('should use custom interval', () => {
		const poll_fn = vi.fn();
		const poller = new Poller({poll_fn, interval: 5_000, immediate: false});

		poller.start();

		// Advance by less than interval
		vi.advanceTimersByTime(4_000);
		expect(poll_fn).not.toHaveBeenCalled();

		// Advance to interval
		vi.advanceTimersByTime(1_000);
		expect(poll_fn).toHaveBeenCalledTimes(1);

		// Advance by another interval
		vi.advanceTimersByTime(5_000);
		expect(poll_fn).toHaveBeenCalledTimes(2);
	});

	test('should stop polling', () => {
		const poll_fn = vi.fn();
		const poller = new Poller({poll_fn});

		poller.start();
		expect(poller.active).toBe(true);
		expect(poll_fn).toHaveBeenCalledTimes(1);

		poller.stop();
		expect(poller.active).toBe(false);

		// Should not poll after stopping
		vi.advanceTimersByTime(Poller.DEFAULT_INTERVAL);
		expect(poll_fn).toHaveBeenCalledTimes(1);
	});

	test('should handle multiple starts safely', () => {
		const poll_fn = vi.fn();
		const poller = new Poller({poll_fn});

		poller.start();
		poller.start();
		poller.start();

		expect(poller.active).toBe(true);
		expect(poll_fn).toHaveBeenCalledTimes(1);

		// Should only have one interval running
		vi.advanceTimersByTime(Poller.DEFAULT_INTERVAL);
		expect(poll_fn).toHaveBeenCalledTimes(2);
	});

	test('should handle multiple stops safely', () => {
		const poll_fn = vi.fn();
		const poller = new Poller({poll_fn});

		poller.start();
		poller.stop();
		poller.stop();
		poller.stop();

		expect(poller.active).toBe(false);
	});

	test('should handle async poll functions', () => {
		const poll_fn = vi.fn().mockResolvedValue('test_result');
		const poller = new Poller({poll_fn});

		poller.start();

		expect(poll_fn).toHaveBeenCalledTimes(1);
		expect(poller.active).toBe(true);

		vi.advanceTimersByTime(Poller.DEFAULT_INTERVAL);
		expect(poll_fn).toHaveBeenCalledTimes(2);
	});

	test('should handle poll function errors gracefully', () => {
		const console_error_spy = vi.spyOn(console, 'error').mockImplementation(() => {
			/* */
		});
		const poll_fn = vi.fn().mockImplementation(() => {
			throw new Error('test_error');
		});
		const poller = new Poller({poll_fn});

		poller.start();

		expect(poll_fn).toHaveBeenCalledTimes(1);
		expect(console_error_spy).toHaveBeenCalledWith(
			'[poller] poll function error:',
			expect.any(Error),
		);
		expect(poller.active).toBe(true);

		// Should continue polling despite error
		vi.advanceTimersByTime(Poller.DEFAULT_INTERVAL);
		expect(poll_fn).toHaveBeenCalledTimes(2);
	});

	test('should handle async poll function errors gracefully', () => {
		const poll_fn = vi.fn().mockRejectedValue(new Error('async_test_error'));
		const poller = new Poller({poll_fn});

		poller.start();

		expect(poll_fn).toHaveBeenCalledTimes(1);
		expect(poller.active).toBe(true);

		// Should continue polling despite async error (error handling is async)
		vi.advanceTimersByTime(Poller.DEFAULT_INTERVAL);
		expect(poll_fn).toHaveBeenCalledTimes(2);
	});

	test('should set interval and restart if active', () => {
		const poll_fn = vi.fn();
		const poller = new Poller({poll_fn, interval: Poller.DEFAULT_INTERVAL, immediate: false});

		poller.start();
		expect(poller.active).toBe(true);

		// Change interval while active
		poller.set_interval(5_000);
		expect(poller.active).toBe(true);

		// Should use new interval
		vi.advanceTimersByTime(5_000);
		expect(poll_fn).toHaveBeenCalledTimes(1);

		vi.advanceTimersByTime(5_000);
		expect(poll_fn).toHaveBeenCalledTimes(2);
	});

	test('should set interval without restarting if inactive', () => {
		const poll_fn = vi.fn();
		const poller = new Poller({poll_fn, interval: Poller.DEFAULT_INTERVAL});

		// Set interval while inactive
		poller.set_interval(5_000);
		expect(poller.active).toBe(false);

		// Start and verify new interval is used
		poller.start();
		vi.advanceTimersByTime(5_000);
		expect(poll_fn).toHaveBeenCalledTimes(2); // immediate + first interval
	});

	test('should be no-op when setting same interval', () => {
		const poll_fn = vi.fn();
		const poller = new Poller({poll_fn, interval: Poller.DEFAULT_INTERVAL});

		poller.start();
		const initial_call_count = poll_fn.mock.calls.length;

		// Set same interval - should be no-op
		poller.set_interval(Poller.DEFAULT_INTERVAL);

		// Should not have restarted
		expect(poll_fn.mock.calls.length).toBe(initial_call_count);
		expect(poller.active).toBe(true);
	});

	test('should dispose and stop polling', () => {
		const poll_fn = vi.fn();
		const poller = new Poller({poll_fn});

		poller.start();
		expect(poller.active).toBe(true);

		poller.dispose();
		expect(poller.active).toBe(false);

		// Should not poll after disposal
		vi.advanceTimersByTime(Poller.DEFAULT_INTERVAL);
		expect(poll_fn).toHaveBeenCalledTimes(1);
	});

	test('should handle restart scenario', () => {
		const poll_fn = vi.fn();
		const poller = new Poller({poll_fn, immediate: false});

		// Start, stop, start cycle
		poller.start();
		expect(poller.active).toBe(true);

		poller.stop();
		expect(poller.active).toBe(false);

		poller.start();
		expect(poller.active).toBe(true);

		// Verify polling works after restart
		vi.advanceTimersByTime(Poller.DEFAULT_INTERVAL);
		expect(poll_fn).toHaveBeenCalledTimes(1);
	});
});
