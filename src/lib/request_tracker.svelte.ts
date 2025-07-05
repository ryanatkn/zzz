// @slop claude_opus_4

import {create_deferred, type Deferred, type Async_Status} from '@ryanatkn/belt/async.js';
import {SvelteMap} from 'svelte/reactivity';

import {Datetime, get_datetime_now} from '$lib/zod_helpers.js';
import {
	JSONRPC_INTERNAL_ERROR,
	type Jsonrpc_Error_Message,
	type Jsonrpc_Request,
	type Jsonrpc_Request_Id,
} from '$lib/jsonrpc.js';

// TODO what if this uses a tracker id param that's an opaque UUID but can be used for action association?

// TODO name, like `Tracked_Request`? or is this implicit namespacing and generic name preferred
/**
 * Represents a pending request with its associated state.
 */
export class Request_Tracker_Item {
	readonly id: Jsonrpc_Request_Id;
	readonly deferred: Deferred<Jsonrpc_Request>;
	readonly created: Datetime;
	status: Async_Status = $state()!;
	timeout: NodeJS.Timeout | undefined = $state();

	constructor(
		id: Jsonrpc_Request_Id,
		deferred: Deferred<Jsonrpc_Request>,
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
export class Request_Tracker {
	readonly pending_requests: SvelteMap<Jsonrpc_Request_Id, Request_Tracker_Item> = new SvelteMap();
	readonly request_timeout_ms: number;

	constructor(request_timeout_ms = 120_000) {
		this.request_timeout_ms = request_timeout_ms;
	}

	/**
	 * Track a new request with the given id.
	 * @param id The request id
	 * @returns A deferred promise that will be resolved when the response is received
	 */
	track_request(id: Jsonrpc_Request_Id): Deferred<any> {
		const deferred = create_deferred<Jsonrpc_Request>();
		const created = get_datetime_now();

		// If we're tracking a request with the same id, clean up the previous one first
		const existing_request = this.pending_requests.get(id);
		if (existing_request?.timeout) {
			clearTimeout(existing_request.timeout);
		}

		// Set up a timeout to automatically reject the request after a delay
		const timeout = setTimeout(() => {
			// Create a proper timeout error message
			this.reject_request(id, {
				jsonrpc: '2.0' as const,
				id,
				error: {code: JSONRPC_INTERNAL_ERROR, message: `request timed out: ${id}`},
			});
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
	resolve_request(id: Jsonrpc_Request_Id, response: Jsonrpc_Request): void {
		const request = this.pending_requests.get(id);
		if (!request) {
			console.warn(`received response for unknown request: ${id}`);
			return;
		}

		// Clear the timeout and resolve the promise
		if (request.timeout) {
			clearTimeout(request.timeout);
			request.timeout = undefined;
		}

		request.status = 'success';
		request.deferred.resolve(response);
		this.pending_requests.delete(id);
	}

	/**
	 * Reject a pending request with the given error.
	 * @param id The request id
	 * @param error The complete Jsonrpc_Error_Message object
	 */
	reject_request(id: Jsonrpc_Request_Id, error: Jsonrpc_Error_Message): void {
		const request = this.pending_requests.get(id);
		if (!request) {
			console.warn(`received error for unknown request: ${id}`);
			return;
		}

		// Clear the timeout and reject the promise
		if (request.timeout) {
			clearTimeout(request.timeout);
			request.timeout = undefined;
		}

		request.status = 'failure';
		request.deferred.reject(error);
		this.pending_requests.delete(id);
	}

	/**
	 * Handle an incoming JSON-RPC message. Resolves or rejects the associated request.
	 * Ignores notifications and unknown/invalid messages.
	 */
	handle_message(message: any): void {
		if (!message) return; // ignore invalid values

		const {id} = message;
		// TODO maybe log a warning/error?
		if (id == null) return; // ignore notifications and errors without ids

		// JSON-RPC responses require both an `id` and either a `result` or `error` field, but not both
		if ('result' in message) {
			this.resolve_request(id, message);
		} else if ('error' in message) {
			this.reject_request(id, message);
		}

		// ignore other messages
	}

	/**
	 * Cancel a pending request.
	 * @param id The request id
	 */
	cancel_request(id: Jsonrpc_Request_Id): void {
		const request = this.pending_requests.get(id);
		if (!request) {
			return;
		}

		if (request.timeout) {
			clearTimeout(request.timeout);
			request.timeout = undefined;
		}

		// We don't reject the promise here, just clean up the tracking
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
				request.timeout = undefined;
			}

			request.status = 'failure';
			request.deferred.reject(new Error(reason || 'request cancelled'));
			this.pending_requests.delete(id);
		}
	}
}
