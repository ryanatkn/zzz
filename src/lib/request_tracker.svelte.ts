import {create_deferred, type Deferred, type Async_Status} from '@ryanatkn/belt/async.js';
import {SvelteMap} from 'svelte/reactivity';

import {Datetime, get_datetime_now} from '$lib/zod_helpers.js';
import type {JSONRPCRequestId} from '$lib/jsonrpc.js';

/**
 * Represents a pending request with its associated state.
 */
export class Request_Tracker_Item<T = any> {
	readonly id: JSONRPCRequestId;
	readonly deferred: Deferred<T>;
	readonly created: Datetime;
	status: Async_Status = $state()!;
	timeout: NodeJS.Timeout | undefined = $state();

	constructor(
		id: JSONRPCRequestId,
		deferred: Deferred<T>,
		created: Datetime,
		status: Async_Status,
		timeout: NodeJS.Timeout | undefined,
	) {
		this.id = id;
		this.deferred = deferred;
		this.created = created;
		this.status = status;
		this.timeout = timeout;
	}
}

/**
 * Tracks RPC requests and their responses to manage promises and timeouts.
 * Used by transports to handle the request-response lifecycle.
 */
export class Request_Tracker<T = any> {
	readonly pending_requests: SvelteMap<JSONRPCRequestId, Request_Tracker_Item<T>> = new SvelteMap();
	readonly request_timeout_ms: number;

	constructor(request_timeout_ms = 15000) {
		this.request_timeout_ms = request_timeout_ms;
	}

	/**
	 * Track a new request with the given id.
	 * @param id The request id
	 * @returns A deferred promise that will be resolved when the response is received
	 */
	track_request(id: JSONRPCRequestId): Deferred<T> {
		const deferred = create_deferred<T>();
		const created = get_datetime_now();

		// If we're tracking a request with the same id, clean up the previous one first
		const existing_request = this.pending_requests.get(id);
		if (existing_request?.timeout) {
			clearTimeout(existing_request.timeout);
		}

		// Set up a timeout to automatically reject the request after a delay
		const timeout = setTimeout(() => {
			this.reject_request(id, new Error(`Request timed out: ${id}`));
		}, this.request_timeout_ms);

		// Store the request tracker using the new class
		this.pending_requests.set(
			id,
			new Request_Tracker_Item(id, deferred, created, 'pending', timeout),
		);

		return deferred;
	}

	/**
	 * Resolve a pending request with the given response data.
	 * @param id The request id
	 * @param response The response data
	 */
	resolve_request(id: JSONRPCRequestId, response: T): void {
		const request = this.pending_requests.get(id);
		if (!request) {
			console.warn(`Received response for unknown request: ${id}`);
			return;
		}

		// Clear the timeout and resolve the promise
		if (request.timeout) {
			clearTimeout(request.timeout);
		}

		request.status = 'success';
		request.deferred.resolve(response);
		this.pending_requests.delete(id);
	}

	/**
	 * Reject a pending request with the given error.
	 * @param id The request id
	 * @param error The error
	 */
	reject_request(id: JSONRPCRequestId, error: any): void {
		const request = this.pending_requests.get(id);
		if (!request) {
			console.warn(`Received error for unknown request: ${id}`);
			return;
		}

		// Clear the timeout and reject the promise
		if (request.timeout) {
			clearTimeout(request.timeout);
		}

		request.status = 'failure';
		request.deferred.reject(error);
		this.pending_requests.delete(id);
	}

	/**
	 * Handle an incoming JSON-RPC message. Resolves or rejects the associated request.
	 * Ignores notifications and unknown/invalid messages.
	 * @param message The JSON-RPC message
	 */
	handle_message(message: any): void {
		console.log(`[handle_message] message`, message);
		if (!message) return; // ignore invalid values
		const {id} = message;
		if (id != null) {
			if (message.error) {
				this.reject_request(id, message.error);
			} else if (Object.hasOwn(message, 'result')) {
				this.resolve_request(id, message.result);
			}
			// Ignore messages with id but no result or error
		}
	}

	/**
	 * Cancel a pending request.
	 * @param id The request id
	 */
	cancel_request(id: JSONRPCRequestId): void {
		const request = this.pending_requests.get(id);
		if (!request) {
			return;
		}

		if (request.timeout) {
			clearTimeout(request.timeout);
		}

		this.pending_requests.delete(id);
	}

	/**
	 * Cancel all pending requests.
	 * @param reason Optional reason to include in rejection
	 */
	cancel_all_requests(reason?: string): void {
		for (const [id, request] of this.pending_requests.entries()) {
			if (request.timeout) {
				clearTimeout(request.timeout);
			}

			request.status = 'failure';
			request.deferred.reject(new Error(reason || 'Request cancelled'));
			this.pending_requests.delete(id);
		}
	}
}
