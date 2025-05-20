// @vitest-environment jsdom

import {test, expect, describe, vi, beforeEach, afterEach} from 'vitest';

import {Request_Tracker} from '$lib/request_tracker.svelte.js';

describe('Request_Tracker', () => {
	let warn_spy: ReturnType<typeof vi.spyOn>;

	beforeEach(() => {
		// Mock console.warn to prevent test output pollution
		warn_spy = vi.spyOn(console, 'warn').mockImplementation(() => {
			/* suppress warnings in test output */
		});

		// Mock setTimeout/clearTimeout for more deterministic tests
		vi.useFakeTimers();
	});

	afterEach(() => {
		warn_spy.mockRestore();
		vi.restoreAllMocks();
		vi.useRealTimers();
	});

	describe('constructor', () => {
		test('creates with default timeout', () => {
			const tracker = new Request_Tracker();

			expect(tracker).toBeInstanceOf(Request_Tracker);
			expect(tracker.request_timeout_ms).toBe(15000);
			expect(tracker.pending_requests.size).toBe(0);
		});

		test('creates with custom timeout', () => {
			const custom_timeout = 5000;
			const tracker = new Request_Tracker(custom_timeout);

			expect(tracker.request_timeout_ms).toBe(custom_timeout);
			expect(tracker.pending_requests).toBeInstanceOf(Map);
		});
	});

	describe('track_request', () => {
		test('creates new tracked request with all expected properties', () => {
			const tracker = new Request_Tracker();
			const id = 'req_1';
			const deferred = tracker.track_request(id);

			// Should return a deferred promise with the correct interface
			expect(deferred).toBeDefined();
			expect(deferred.promise).toBeInstanceOf(Promise);
			expect(deferred.resolve).toBeInstanceOf(Function);
			expect(deferred.reject).toBeInstanceOf(Function);

			// Request should be stored with the correct properties
			expect(tracker.pending_requests.has(id)).toBe(true);

			const request = tracker.pending_requests.get(id);
			expect(request).toBeDefined();
			expect(request?.deferred).toBe(deferred);
			expect(request?.status).toBe('pending');
			expect(request?.timeout).toBeDefined();
			expect(request?.created).toBeDefined();
			expect(typeof request?.created).toBe('string');

			// Clean up
			tracker.cancel_request(id);
		});

		test('creates unique request trackers for different ids', async () => {
			const tracker = new Request_Tracker();
			const id1 = 'req_1';
			const id2 = 'req_2';

			const deferred1 = tracker.track_request(id1);
			const deferred2 = tracker.track_request(id2);

			expect(deferred1).not.toBe(deferred2);
			expect(tracker.pending_requests.size).toBe(2);
			expect(tracker.pending_requests.get(id1)?.deferred).toBe(deferred1);
			expect(tracker.pending_requests.get(id2)?.deferred).toBe(deferred2);

			// Clean up
			const promise1 = deferred1.promise.catch(() => {
				/* expected */
			});
			const promise2 = deferred2.promise.catch(() => {
				/* expected */
			});
			tracker.cancel_all_requests();
			await Promise.allSettled([promise1, promise2]);
		});

		test('automatically times out requests after specified delay', async () => {
			const tracker = new Request_Tracker(1000); // 1 second timeout
			const id = 'timeout_req';

			const deferred = tracker.track_request(id);
			let rejection_error: Error | undefined;

			const promise = deferred.promise.catch((err) => {
				rejection_error = err as Error;
			});

			expect(tracker.pending_requests.has(id)).toBe(true);

			// Fast-forward time to trigger timeout
			vi.advanceTimersByTime(1001);

			await Promise.allSettled([promise]);

			// Request should be removed and promise rejected with timeout error
			expect(tracker.pending_requests.has(id)).toBe(false);
			expect(rejection_error).toBeDefined();
			expect(rejection_error?.message).toBe(`Request timed out: ${id}`);
		});

		test('cleans up previous request with same id', () => {
			const tracker = new Request_Tracker();
			const id = 'duplicate_req';

			const clear_timeout_spy = vi.spyOn(global, 'clearTimeout');

			// Track first request
			const deferred1 = tracker.track_request(id);
			const timeout1 = tracker.pending_requests.get(id)?.timeout;
			expect(timeout1).toBeDefined();

			// Track second request with same id
			const deferred2 = tracker.track_request(id);

			// Verify timeout was cleared for first request
			expect(clear_timeout_spy).toHaveBeenCalledWith(timeout1);
			expect(deferred1).not.toBe(deferred2);

			// Only one request should exist
			expect(tracker.pending_requests.size).toBe(1);
			expect(tracker.pending_requests.get(id)?.deferred).toBe(deferred2);

			// Clean up
			tracker.cancel_request(id);
		});
	});

	describe('resolve_request', () => {
		test('resolves tracked request with value', async () => {
			const tracker = new Request_Tracker();
			const id = 'req_1';
			const value = {result: 'success'};

			const deferred = tracker.track_request(id);
			const clear_timeout_spy = vi.spyOn(global, 'clearTimeout');
			const timeout = tracker.pending_requests.get(id)?.timeout;

			// Resolve the request
			tracker.resolve_request(id, value);

			// Verify timeout was cleared
			expect(clear_timeout_spy).toHaveBeenCalledWith(timeout);

			// Verify request status was updated before resolution
			expect(tracker.pending_requests.has(id)).toBe(false);

			// Verify promise resolves with correct value
			const result = await deferred.promise;
			expect(result).toBe(value);
		});

		test('logs warning for unknown request id', () => {
			const tracker = new Request_Tracker();
			const unknown_id = 'unknown_req';

			tracker.resolve_request(unknown_id, 'test');

			expect(warn_spy).toHaveBeenCalledTimes(1);
			expect(warn_spy).toHaveBeenCalledWith(`Received response for unknown request: ${unknown_id}`);
		});

		test('handles various data types as response values', async () => {
			const tracker = new Request_Tracker();
			const test_cases = [
				{id: 'string_req', value: 'string value'},
				{id: 'number_req', value: 123},
				{id: 'boolean_req', value: true},
				{id: 'null_req', value: null},
				{id: 'object_req', value: {a: 1, b: 2}},
				{id: 'array_req', value: [1, 2, 3]},
			];

			const promises = test_cases.map(async ({id, value}) => {
				const deferred = tracker.track_request(id);
				tracker.resolve_request(id, value);
				const result = await deferred.promise;
				expect(result).toBe(value);
			});

			await Promise.all(promises);
		});
	});

	describe('reject_request', () => {
		test('rejects tracked request with error and cleans up', async () => {
			const tracker = new Request_Tracker();
			const id = 'req_1';
			const error = new Error('test error');

			const deferred = tracker.track_request(id);
			const clear_timeout_spy = vi.spyOn(global, 'clearTimeout');
			const timeout = tracker.pending_requests.get(id)?.timeout;

			// Reject the request
			tracker.reject_request(id, error);

			// Verify timeout was cleared
			expect(clear_timeout_spy).toHaveBeenCalledWith(timeout);
			expect(tracker.pending_requests.has(id)).toBe(false);

			// Verify promise rejects with the correct error
			await expect(deferred.promise).rejects.toBe(error);
		});

		test('logs warning for unknown request id', () => {
			const tracker = new Request_Tracker();
			const unknown_id = 'unknown_req';

			tracker.reject_request(unknown_id, new Error('test'));

			expect(warn_spy).toHaveBeenCalledTimes(1);
			expect(warn_spy).toHaveBeenCalledWith(`Received error for unknown request: ${unknown_id}`);
		});

		test('handles various error types', async () => {
			const tracker = new Request_Tracker();
			const test_cases = [
				{id: 'error_req', error: new Error('standard error')},
				{id: 'string_req', error: 'string error'},
				{id: 'object_req', error: {code: -32000, message: 'object error'}},
			];

			for (const {id, error} of test_cases) {
				const deferred = tracker.track_request(id);
				tracker.reject_request(id, error);
				await expect(deferred.promise).rejects.toBe(error); // eslint-disable-line no-await-in-loop
				expect(tracker.pending_requests.has(id)).toBe(false);
			}
		});
	});

	describe('handle_message', () => {
		test('resolves request with result when message contains result', async () => {
			const tracker = new Request_Tracker();
			const id = 'req_1';
			const result = {data: 'test_result'};
			const resolve_spy = vi.spyOn(tracker, 'resolve_request');

			// Track request
			const deferred = tracker.track_request(id);

			// Handle message
			tracker.handle_message({id, result});

			// Verify resolve_request was called with correct arguments
			expect(resolve_spy).toHaveBeenCalledWith(id, result);

			// Verify promise resolves with correct value
			const response = await deferred.promise;
			expect(response).toBe(result);
			expect(tracker.pending_requests.has(id)).toBe(false);
		});

		test('rejects request with error when message contains error', async () => {
			const tracker = new Request_Tracker();
			const id = 'req_2';
			const error = {code: -32000, message: 'test error'};
			const reject_spy = vi.spyOn(tracker, 'reject_request');

			// Track request
			const deferred = tracker.track_request(id);

			// Handle message
			tracker.handle_message({id, error});

			// Verify reject_request was called with correct arguments
			expect(reject_spy).toHaveBeenCalledWith(id, error);

			// Verify promise rejects with correct error
			await expect(deferred.promise).rejects.toBe(error);
			expect(tracker.pending_requests.has(id)).toBe(false);
		});

		test('ignores notification messages (no id)', () => {
			const tracker = new Request_Tracker();
			const resolve_spy = vi.spyOn(tracker, 'resolve_request');
			const reject_spy = vi.spyOn(tracker, 'reject_request');

			// Track a request to verify it's not affected
			const id = 'req_3';
			tracker.track_request(id);

			// Handle notification (no id)
			tracker.handle_message({method: 'notification', params: {}});

			// Verify no resolve/reject was called
			expect(resolve_spy).not.toHaveBeenCalled();
			expect(reject_spy).not.toHaveBeenCalled();

			// Original request should still be pending
			expect(tracker.pending_requests.has(id)).toBe(true);

			// Clean up
			tracker.cancel_request(id);
		});

		test('ignores messages with id but no result or error', () => {
			const tracker = new Request_Tracker();
			const resolve_spy = vi.spyOn(tracker, 'resolve_request');
			const reject_spy = vi.spyOn(tracker, 'reject_request');

			// Create a tracked request
			const id = 'req_4';
			tracker.track_request(id);

			// Handle message with id but no result/error
			tracker.handle_message({id: 'test_id', method: 'test'});

			// Verify no resolve/reject was called
			expect(resolve_spy).not.toHaveBeenCalled();
			expect(reject_spy).not.toHaveBeenCalled();

			// Original request should still be pending
			expect(tracker.pending_requests.has(id)).toBe(true);

			// Clean up
			tracker.cancel_request(id);
		});

		test('handles null/undefined/empty messages gracefully', () => {
			const tracker = new Request_Tracker();
			const resolve_spy = vi.spyOn(tracker, 'resolve_request');
			const reject_spy = vi.spyOn(tracker, 'reject_request');

			// Create a tracked request to verify it's not affected
			const id = 'req_5';
			tracker.track_request(id);

			// Handle various invalid messages
			tracker.handle_message(null);
			tracker.handle_message(undefined);
			tracker.handle_message({});

			// Verify no resolve/reject was called
			expect(resolve_spy).not.toHaveBeenCalled();
			expect(reject_spy).not.toHaveBeenCalled();

			// Original request should still be pending
			expect(tracker.pending_requests.has(id)).toBe(true);

			// Clean up
			tracker.cancel_request(id);
		});

		test('correctly handles zero as a valid id', () => {
			const tracker = new Request_Tracker();
			const id = 0;
			const result = 'zero id result';
			const resolve_spy = vi.spyOn(tracker, 'resolve_request');

			// Track request with zero id
			tracker.track_request(id);

			// Handle message
			tracker.handle_message({id, result});

			// Verify resolve_request was called with correct arguments
			expect(resolve_spy).toHaveBeenCalledWith(id, result);
			expect(tracker.pending_requests.has(id)).toBe(false);
		});
	});

	describe('cancel_request', () => {
		test('cancels tracked request and cleans up timeouts', () => {
			const tracker = new Request_Tracker();
			const id = 'req_1';

			tracker.track_request(id);
			const clear_timeout_spy = vi.spyOn(global, 'clearTimeout');
			const timeout = tracker.pending_requests.get(id)?.timeout;

			tracker.cancel_request(id);

			// Verify timeout was cleared
			expect(clear_timeout_spy).toHaveBeenCalledWith(timeout);

			// Request should be removed
			expect(tracker.pending_requests.has(id)).toBe(false);
		});

		test('does nothing for unknown request id', () => {
			const tracker = new Request_Tracker();
			const unknown_id = 'unknown_req';
			const clear_timeout_spy = vi.spyOn(global, 'clearTimeout');

			tracker.cancel_request(unknown_id);

			// Should not attempt to clear any timeout
			expect(clear_timeout_spy).not.toHaveBeenCalled();
		});

		test('handles cancel without affecting other requests', () => {
			const tracker = new Request_Tracker();
			const id1 = 'req_1';
			const id2 = 'req_2';

			tracker.track_request(id1);
			tracker.track_request(id2);

			tracker.cancel_request(id1);

			// Only the specified request should be removed
			expect(tracker.pending_requests.has(id1)).toBe(false);
			expect(tracker.pending_requests.has(id2)).toBe(true);

			// Clean up
			tracker.cancel_request(id2);
		});
	});

	describe('cancel_all_requests', () => {
		test('cancels all tracked requests with custom reason', async () => {
			const tracker = new Request_Tracker();
			const id1 = 'req_1';
			const id2 = 'req_2';
			const custom_reason = 'Custom cancel reason';

			const clear_timeout_spy = vi.spyOn(global, 'clearTimeout');

			const deferred1 = tracker.track_request(id1);
			const deferred2 = tracker.track_request(id2);

			const timeout1 = tracker.pending_requests.get(id1)?.timeout;
			const timeout2 = tracker.pending_requests.get(id2)?.timeout;

			// Set up promise rejection tracking
			const promise1 = expect(deferred1.promise).rejects.toThrow(custom_reason);
			const promise2 = expect(deferred2.promise).rejects.toThrow(custom_reason);

			// Cancel all requests
			tracker.cancel_all_requests(custom_reason);

			// Verify timeouts were cleared
			expect(clear_timeout_spy).toHaveBeenCalledWith(timeout1);
			expect(clear_timeout_spy).toHaveBeenCalledWith(timeout2);

			// All requests should be removed
			expect(tracker.pending_requests.size).toBe(0);

			// Wait for promise rejections to complete
			await Promise.allSettled([promise1, promise2]);
		});

		test('uses default message when reason not provided', async () => {
			const tracker = new Request_Tracker();
			const id = 'req_1';

			const deferred = tracker.track_request(id);
			const promise = expect(deferred.promise).rejects.toThrow('Request cancelled');

			tracker.cancel_all_requests();
			expect(tracker.pending_requests.size).toBe(0);

			await promise;
		});

		test('does nothing when no requests are tracked', () => {
			const tracker = new Request_Tracker();
			const clear_timeout_spy = vi.spyOn(global, 'clearTimeout');

			tracker.cancel_all_requests();

			// Should not attempt to clear any timeouts
			expect(clear_timeout_spy).not.toHaveBeenCalled();
		});

		test('sets failure status before rejecting', async () => {
			const tracker = new Request_Tracker();
			const id = 'req_1';

			// Track request but keep reference to the tracker item
			tracker.track_request(id);
			const request = tracker.pending_requests.get(id)!;

			// Set up a spy to track when the status is set
			let status_when_rejected: string | null = null;
			const original_reject = request.deferred.reject;
			request.deferred.reject = function (reason) {
				status_when_rejected = request.status;
				original_reject.call(this, reason);
			};

			const promise = request.deferred.promise.catch(() => {
				/* expected */
			});

			tracker.cancel_all_requests();
			await promise;

			expect(status_when_rejected).toBe('failure');
		});
	});

	describe('edge cases and corner cases', () => {
		test('retracking the same request id replaces previous tracking', () => {
			const tracker = new Request_Tracker();
			const id = 'req_1';
			const clear_timeout_spy = vi.spyOn(global, 'clearTimeout');

			// Track first request
			const deferred1 = tracker.track_request(id);
			const timeout1 = tracker.pending_requests.get(id)?.timeout;

			// Track second request with same ID
			const deferred2 = tracker.track_request(id);

			// Should be different deferred objects
			expect(deferred1).not.toBe(deferred2);
			expect(tracker.pending_requests.size).toBe(1);
			expect(tracker.pending_requests.get(id)?.deferred).toBe(deferred2);

			// Should have cleared the timeout from the first request
			expect(clear_timeout_spy).toHaveBeenCalledWith(timeout1);

			// Clean up
			tracker.cancel_request(id);
		});

		test('handles various JSONRPCRequestId types', async () => {
			const tracker = new Request_Tracker();
			const test_cases = [
				{id: 123, value: 'numeric id'},
				{id: 'string-id', value: 'string id'},
				{id: 0, value: 'zero id'},
				{id: '', value: 'empty string id'},
			];

			for (const {id, value} of test_cases) {
				const deferred = tracker.track_request(id);
				expect(tracker.pending_requests.has(id)).toBe(true);

				tracker.resolve_request(id, value);
				expect(tracker.pending_requests.has(id)).toBe(false);

				const result = await deferred.promise; // eslint-disable-line no-await-in-loop
				expect(result).toBe(value);
			}
		});

		test('handles Object.hasOwn correctly for result property checking', async () => {
			const tracker = new Request_Tracker();
			const id = 'req_1';
			const deferred = tracker.track_request(id);

			// Message with result: null (should be handled correctly)
			tracker.handle_message({id, result: null});

			const result = await deferred.promise;
			expect(result).toBe(null);
			expect(tracker.pending_requests.has(id)).toBe(false);
		});

		test('handles message object with result that inherits from prototype', () => {
			const tracker = new Request_Tracker();
			const id = 'req_proto';
			tracker.track_request(id);

			// Create an object with result in prototype chain
			const proto = {result: 'prototype result'};
			const message = Object.create(proto);
			message.id = id;

			// Should not resolve since result is not own property
			tracker.handle_message(message);

			// Request should still be pending
			expect(tracker.pending_requests.has(id)).toBe(true);

			// Clean up to avoid unhandled rejection
			tracker.cancel_request(id);
		});

		test('request timeout uses Error instance with correct message', async () => {
			const tracker = new Request_Tracker(100);
			const id = 'timeout_req';

			const deferred = tracker.track_request(id);

			// Set up expectation for rejection
			const promise = expect(deferred.promise).rejects.toBeInstanceOf(Error);
			const error_promise = expect(deferred.promise).rejects.toThrow(`Request timed out: ${id}`);

			// Fast-forward time to trigger timeout
			vi.advanceTimersByTime(101);

			await Promise.allSettled([promise, error_promise]);
		});
	});
});
