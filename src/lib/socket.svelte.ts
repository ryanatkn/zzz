// @slop Claude Sonnet 3.7

import {z} from 'zod';
import {SvelteMap} from 'svelte/reactivity';
import type {Async_Status} from '@ryanatkn/belt/async.js';
import {BROWSER} from 'esm-env';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {create_uuid, Uuid} from '$lib/zod_helpers.js';
import {
	DEFAULT_HEARTBEAT_INTERVAL,
	DEFAULT_RECONNECT_DELAY,
	DEFAULT_RECONNECT_DELAY_MAX,
	DEFAULT_AUTO_RECONNECT,
	DEFAULT_CLOSE_CODE,
} from '$lib/socket_helpers.js';
import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';

// TODO the plan here is to make websockets one of multiple transports, this just gets the proof of concept working

export const Socket_Json = Cell_Json.extend({
	url: z.string().nullable().default(null),
	url_input: z.string().default(''),
	heartbeat_interval: z.number().int().positive().default(DEFAULT_HEARTBEAT_INTERVAL),
	reconnect_delay: z.number().int().positive().default(DEFAULT_RECONNECT_DELAY),
	reconnect_delay_max: z.number().int().positive().default(DEFAULT_RECONNECT_DELAY_MAX),
	auto_reconnect: z.boolean().default(DEFAULT_AUTO_RECONNECT),
});
export type Socket_Json = z.infer<typeof Socket_Json>;
export type Socket_Json_Input = z.input<typeof Socket_Json>;

export interface Socket_Options extends Cell_Options<typeof Socket_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export type Socket_Action_Handler = (event: MessageEvent) => void;
export type Socket_Error_Handler = (event: Event) => void;

// TODO add schemas following the other cell patterns so it can be serialized (so the full state can be snapshotted, and all queued/failed messages restored)

/**
 * Queued message that couldn't be sent immediately.
 */
export interface Queued_Message {
	id: Uuid;
	data: any;
	created: number;
}

/**
 * Failed message that exceeded retry count.
 */
export interface Failed_Message extends Queued_Message {
	failed: number;
	reason: string;
}

/**
 * Socket class for WebSocket connection management with auto-reconnect and message queueing.
 */
export class Socket extends Cell<typeof Socket_Json> {
	// Private serializable state with getters/setters
	#url: string | null = $state()!;
	#url_input: string = $state()!; // TODO better name? is ambiguous, it's un-applied (not quite unsaved/temporary)
	#heartbeat_interval: number = $state()!;
	#reconnect_delay: number = $state()!;
	#reconnect_delay_max: number = $state()!;
	#auto_reconnect: boolean = $state()!;

	// Runtime-only state (not serialized)
	ws: WebSocket | null = $state(null);
	open: boolean = $state(false);
	status: Async_Status = $state('initial'); // 'initial' | 'pending' | 'success' | 'failure'
	last_send_time: number | null = $state(null);
	last_receive_time: number | null = $state(null);
	last_connect_time: number | null = $state(null);
	heartbeat_timeout: NodeJS.Timeout | null = $state(null);

	// Keep track of connection attempts
	reconnect_count: number = $state(0);
	reconnect_attempt: number = $state(0); // increments on each reconnect attempt for animation triggering
	reconnect_timeout: NodeJS.Timeout | null = $state(null);
	current_reconnect_delay: number = $state(0);

	// TODO need to think about garbage cleanup
	// Message handling
	message_queue: Array<Queued_Message> = $state([]);
	failed_messages: SvelteMap<string, Failed_Message> = new SvelteMap();

	// Event handlers - can be assigned by consumers
	onmessage: Socket_Action_Handler | null = $state(null);
	onerror: Socket_Error_Handler | null = $state(null);

	// Derived properties
	readonly connected: boolean = $derived(this.open && this.status === 'success');
	readonly can_send: boolean = $derived(this.connected && this.ws !== null);
	readonly has_queued_messages: boolean = $derived(this.message_queue.length > 0);
	readonly queued_message_count: number = $derived(this.message_queue.length);
	readonly failed_message_count: number = $derived(this.failed_messages.size);

	// Time tracking and formatting
	readonly connection_duration: number | null = $derived(
		this.connected && this.last_connect_time
			? Math.max(0, this.app.time.now_ms - this.last_connect_time) // `Math.max` is needed to avoid negative values with the coarse value of `now_ms`
			: null,
	);
	readonly connection_duration_rounded: number | null = $derived(
		this.connection_duration !== null
			? Math.round(this.connection_duration / this.app.time.interval) * this.app.time.interval
			: null,
	);

	// Getters and setters for serializable state
	get url(): string | null {
		return this.#url;
	}
	set url(value: string | null) {
		this.#url = Socket_Json.shape.url.parse(value);
	}

	get url_input(): string {
		return this.#url_input;
	}
	set url_input(value: string) {
		this.#url_input = Socket_Json.shape.url_input.parse(value);
	}

	get heartbeat_interval(): number {
		return this.#heartbeat_interval;
	}
	set heartbeat_interval(value: number) {
		this.#heartbeat_interval = Socket_Json.shape.heartbeat_interval.parse(value);
	}

	get reconnect_delay(): number {
		return this.#reconnect_delay;
	}
	set reconnect_delay(value: number) {
		this.#reconnect_delay = Socket_Json.shape.reconnect_delay.parse(value);
	}

	get reconnect_delay_max(): number {
		return this.#reconnect_delay_max;
	}
	set reconnect_delay_max(value: number) {
		this.#reconnect_delay_max = Socket_Json.shape.reconnect_delay_max.parse(value);
	}

	get auto_reconnect(): boolean {
		return this.#auto_reconnect;
	}
	set auto_reconnect(value: boolean) {
		this.#auto_reconnect = Socket_Json.shape.auto_reconnect.parse(value);
	}

	constructor(options: Socket_Options) {
		super(Socket_Json, options);
		this.init();

		// Initialize url_input if url exists
		if (this.url) {
			this.url_input = this.url;
		}
	}

	/**
	 * Connects to the WebSocket server.
	 * @param url The WebSocket URL to connect to
	 */
	connect(url: string | null = null): void {
		// Skip connection attempt on the server side
		if (!BROWSER) return;

		// Disconnect existing connection if any
		this.disconnect();

		// If URL is provided, update both url and url_input
		if (url !== null) {
			this.url = url;
			this.url_input = url;
		} else if (this.url_input) {
			// If no URL provided but url_input has value, use that
			this.url = this.url_input;
		}

		if (!this.url) {
			console.error('Cannot connect: no URL provided');
			return;
		}

		try {
			this.status = 'pending';
			const ws = new WebSocket(this.url);
			this.ws = ws;

			ws.addEventListener('open', this.#handle_open);
			ws.addEventListener('close', this.#handle_close);
			ws.addEventListener('error', this.#handle_error);
			ws.addEventListener('message', this.#handle_message);
		} catch (error) {
			console.error('failed to create WebSocket:', error);
			this.ws = null;
			this.open = false;
			this.status = 'failure';
			this.#maybe_reconnect(); // Trigger reconnect for synchronous errors
		}
	}

	/**
	 * Disconnects from the WebSocket server.
	 * @param code The close code to use (default: 1000 - normal closure)
	 */
	disconnect(code: number = DEFAULT_CLOSE_CODE): void {
		this.#cancel_reconnect();
		this.#stop_heartbeat();

		if (this.ws) {
			this.ws.removeEventListener('open', this.#handle_open);
			this.ws.removeEventListener('close', this.#handle_close);
			this.ws.removeEventListener('error', this.#handle_error);
			this.ws.removeEventListener('message', this.#handle_message);

			// Only call close() if the connection is open
			if (this.open) {
				try {
					this.ws.close(code);
				} catch (error) {
					console.error('Error closing WebSocket:', error);
				}
			}

			this.ws = null;
			this.open = false;
		}

		this.status = 'initial';
	}

	/**
	 * Sends a message through the WebSocket.
	 * @param data The data to send
	 * @returns True if the message was sent immediately, false if queued or failed
	 */
	send(data: object): boolean {
		if (this.can_send) {
			try {
				this.ws!.send(JSON.stringify(data));
				this.last_send_time = Date.now();
				return true;
			} catch (error) {
				console.error('error sending message:', error);
				this.#queue_message(data);
				return false;
			}
		} else {
			this.#queue_message(data);
			return false;
		}
	}

	/**
	 * Updates the connection URL and reconnects if currently connected.
	 * @param url The new WebSocket URL
	 */
	update_url(url: string): void {
		if (this.url === url) return;

		const was_connected = this.connected;

		this.url = url;
		this.url_input = url;

		if (was_connected) {
			this.connect();
		}
	}

	/**
	 * Sends a ping message for heartbeat purposes
	 */
	async send_heartbeat(): Promise<void> {
		await this.app.api.ping(); // TODO @api need to force websocket transport, second arg?
	}

	/**
	 * Retry sending all queued messages.
	 */
	retry_queued_messages(): void {
		if (!this.can_send || this.message_queue.length === 0) return;

		// Create a copy to avoid mutation issues during iteration
		const queue_copy = [...this.message_queue];
		this.message_queue = [];

		for (const message of queue_copy) {
			this.#process_queued_message(message);
		}
	}

	/**
	 * Clear the failed messages list
	 */
	clear_failed_messages(): void {
		this.failed_messages.clear();
	}

	// Private methods

	#queue_message(data: object): void {
		const message: Queued_Message = {
			id: create_uuid(),
			data,
			created: Date.now(),
		};
		this.message_queue.push(message);

		// Try to connect if not already connecting/connected
		if (this.status === 'initial' && this.auto_reconnect) {
			this.connect();
		}
	}

	#process_queued_message(message: Queued_Message): void {
		if (!this.can_send) {
			// Put back in queue if we can't send now
			this.message_queue.push(message);
			return;
		}

		try {
			// TODO need the round-trip protocol, this is a hack
			this.ws!.send(JSON.stringify(message.data));
			this.last_send_time = Date.now();
		} catch (error) {
			// Mark as failed immediately since we don't have retry count anymore
			const failed_message: Failed_Message = {
				...message,
				failed: Date.now(),
				reason: error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE,
			};
			this.failed_messages.set(message.id, failed_message);
		}
	}

	#start_heartbeat(): void {
		this.#stop_heartbeat();

		const now = Date.now();
		this.last_send_time = now;
		this.last_receive_time = now;

		this.#schedule_next_heartbeat();
	}

	#schedule_next_heartbeat(): void {
		this.#stop_heartbeat();

		this.heartbeat_timeout = setTimeout(
			() => {
				// Only send heartbeat if we need to based on last activity
				const now = Date.now();
				const next_timeout_time = this.#get_next_heartbeat_time();

				if (next_timeout_time <= now) {
					void this.send_heartbeat();
				}

				this.#schedule_next_heartbeat();
			},
			Math.max(100, this.#get_next_heartbeat_time() - Date.now()),
		);
	}

	#get_next_heartbeat_time(): number {
		const last_activity = Math.max(this.last_send_time ?? 0, this.last_receive_time ?? 0);
		return last_activity + this.heartbeat_interval;
	}

	#stop_heartbeat(): void {
		if (this.heartbeat_timeout !== null) {
			clearTimeout(this.heartbeat_timeout);
			this.heartbeat_timeout = null;
		}
	}

	#maybe_reconnect(): void {
		if (!this.auto_reconnect) return;

		this.#cancel_reconnect();

		this.reconnect_count++;
		this.reconnect_attempt++; // increment for animation triggering
		this.current_reconnect_delay = Math.round(
			Math.min(this.reconnect_delay_max, this.reconnect_delay * 1.5 ** (this.reconnect_count - 1)),
		);

		this.reconnect_timeout = setTimeout(() => {
			this.reconnect_timeout = null;
			this.connect();
		}, this.current_reconnect_delay);
	}

	// Public method that delegates to private implementation
	maybe_reconnect(): void {
		this.#maybe_reconnect();
	}

	/**
	 * Cancel any pending reconnection attempt.
	 */
	cancel_reconnect(): void {
		this.#cancel_reconnect();
	}

	#cancel_reconnect(): void {
		if (this.reconnect_timeout !== null) {
			clearTimeout(this.reconnect_timeout);
			this.reconnect_timeout = null;
		}
	}

	// Event handlers

	#handle_open = (_: Event): void => {
		this.open = true;
		this.status = 'success';
		this.reconnect_count = 0;
		this.#cancel_reconnect();
		this.#start_heartbeat();
		this.last_connect_time = Date.now();

		// Try to send any queued messages
		if (this.has_queued_messages) {
			this.retry_queued_messages();
		}
	};

	#handle_close = (_: CloseEvent): void => {
		this.open = false;

		// Only change status and try to reconnect if this wasn't initiated by the client
		if (this.status === 'success' || this.status === 'pending') {
			this.status = 'failure';
			this.#maybe_reconnect();
		}
	};

	#handle_error = (event: Event): void => {
		this.onerror?.(event);

		console.error('WebSocket error occurred:', event);
		this.status = 'failure';

		// The WebSocket will close after an error, but we need to make sure
		// the socket state is updated now in case close doesn't fire for some reason
		this.open = false;

		// Some errors might not trigger the close event, so we force a reconnection attempt
		// This ensures we don't get stuck when errors occur
		this.#maybe_reconnect();
	};

	#handle_message = (event: MessageEvent): void => {
		this.last_receive_time = Date.now();

		this.onmessage?.(event);
	};
}
