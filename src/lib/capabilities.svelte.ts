// @slop Claude Sonnet 3.7

import {z} from 'zod';
import type {Async_Status} from '@ryanatkn/belt/async.js';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import type {Zzz_Dir} from '$lib/diskfile_types.js';
import type {Jsonrpc_Request_Id} from '$lib/jsonrpc.js';
import type {
	Ollama_List_Response,
	Ollama_List_Response_Item,
	Ollama_Ps_Response,
} from '$lib/ollama_helpers.js';

// TODO extract reusable stuff to make this generic

/** Maximum number of ping records to keep. */
export const PING_HISTORY_MAX = 6;

export const Capabilities_Json = Cell_Json.extend({});
export type Capabilities_Json = z.infer<typeof Capabilities_Json>;
export type Capabilities_Json_Input = z.input<typeof Capabilities_Json>;

/**
 * Generic interface for a capability with standardized status tracking.
 */
export interface Capability<T> {
	/** The capability name. */
	name: string;
	/** The capability's status: undefined=not initialized, null=checking, otherwise available or not. */
	data: T;
	/** Async status tracking the connection/check state. */
	status: Async_Status;
	/** Message id of the last request for this capability's info, if any. */
	message_id: Jsonrpc_Request_Id | null;
	/** Error message if any */
	error_message: string | null;
	/** Timestamp when the capability was last checked. */
	updated: number | null;
}

export interface Ping_Data {
	ping_id: Jsonrpc_Request_Id;
	completed: boolean;
	sent_time: number;
	received_time: number | null;
	round_trip_time: number | null;
}

export interface Server_Capability_Data {
	// TODO think about a special endpoint that isn't `ping` with more info, maybe in .well-known as a json file - server.json?
	// name: string;
	// version: string;
	round_trip_time: number;
}

export interface Websocket_Capability_Data {
	url: string | null;
	connected: boolean;
	reconnect_count: number;
	last_connect_time: number | null;
	last_send_time: number | null;
	last_receive_time: number | null;
	connection_duration: number | null;
	pending_pings: number;
}

export interface Filesystem_Capability_Data {
	zzz_dir: Zzz_Dir | null | undefined;
	zzz_cache_dir: string | null | undefined;
}

export interface Ollama_Capability_Data {
	list_response: Ollama_List_Response | null;
	ps_response: Ollama_Ps_Response | null;
	round_trip_time: number | null;
}

/**
 * A class that encapsulates system capabilities detection and management.
 * This is NOT generic or extensible - it contains hardcoded logic for
 * all capabilities the system supports.
 */
export class Capabilities extends Cell<typeof Capabilities_Json> {
	backend: Capability<Server_Capability_Data | null | undefined> = $state.raw({
		name: 'backend',
		data: undefined,
		status: 'initial',
		message_id: null,
		error_message: null,
		updated: null,
	});

	/**
	 * WebSocket capability that derives its state from the socket.
	 */
	readonly websocket: Capability<Websocket_Capability_Data | null | undefined> = $derived.by(() => {
		// Map socket status to capability status, but consider connection state
		const {socket} = this.app;
		const {status} = socket;

		// Socket is available if we're connected,
		// otherwise it's not available but we have data about its state
		const data =
			status === 'initial'
				? undefined
				: {
						url: socket.url,
						connected: socket.connected,
						reconnect_count: socket.reconnect_count,
						last_connect_time: socket.last_connect_time,
						last_send_time: socket.last_send_time,
						last_receive_time: socket.last_receive_time,
						connection_duration: socket.connection_duration,
						pending_pings: this.pending_ping_count, // Update to use new count
					};

		return {
			name: 'websocket',
			data,
			status,
			message_id: null,
			error_message: null, // Socket doesn't expose error messages directly
			updated: data?.last_connect_time ?? null,
		};
	});

	/**
	 * The filesystem capability derives its state from the backend and `zzz_dir`.
	 */
	readonly filesystem: Capability<Filesystem_Capability_Data | null | undefined> = $derived.by(
		() => {
			const {zzz_dir, zzz_cache_dir} = this.app;
			let status: Async_Status;

			if (this.backend.status !== 'success') {
				// Server is not available, so mirror its status
				status = this.backend.status;
			} else {
				// TODO hacky, should be explicit
				if (zzz_cache_dir === undefined) {
					status = 'initial';
				} else if (zzz_cache_dir === null) {
					status = 'pending';
				} else if (zzz_cache_dir === '') {
					status = 'failure';
				} else {
					status = 'success';
				}
			}

			return {
				name: 'filesystem',
				data: status === 'success' ? {zzz_dir, zzz_cache_dir} : undefined,
				status,
				message_id: null,
				error_message: null,
				updated: Date.now(),
			};
		},
	);

	/**
	 * Ollama capability that derives its state from app.ollama.
	 */
	readonly ollama: Capability<Ollama_Capability_Data | null | undefined> = $derived.by(() => {
		const {ollama} = this.app;
		const {list_status} = ollama;

		return {
			name: 'ollama',
			data:
				list_status === 'initial'
					? undefined
					: list_status === 'success'
						? {
								list_response: ollama.list_response,
								ps_response: ollama.ps_response,
								round_trip_time: ollama.list_round_trip_time,
							}
						: null,
			status: list_status,
			message_id: null,
			error_message: ollama.list_error,
			updated: ollama.list_last_updated,
		};
	});

	/**
	 * Store pings - both pending and completed.
	 */
	pings: Array<Ping_Data> = $state([]);

	/**
	 * Most recent completed ping round trip time in milliseconds.
	 */
	readonly latest_ping_time: number | null = $derived(
		this.pings.find((p) => p.completed)?.round_trip_time ?? null,
	);

	/**
	 * Completed pings (for display).
	 */
	readonly completed_pings: Array<Ping_Data> = $derived(this.pings.filter((p) => p.completed));

	/**
	 * Number of pending pings.
	 */
	readonly pending_ping_count: number = $derived(this.pings.filter((p) => !p.completed).length);

	/**
	 * Has pending pings.
	 */
	readonly has_pending_pings: boolean = $derived(this.pending_ping_count > 0);

	/**
	 * Convenience accessor for backend availability.
	 * `undefined` means uninitialized, `null` means loading/checking.
	 * boolean indicates if available.
	 */
	readonly backend_available: boolean | null | undefined = $derived(
		this.backend.data === undefined
			? undefined
			: this.backend.status === 'pending'
				? null
				: this.backend.status === 'success' && this.backend.data !== null,
	);

	/**
	 * Convenience accessor for ollama availability.
	 * `undefined` means uninitialized, `null` means loading/checking.
	 * boolean indicates if available.
	 */
	readonly ollama_available: boolean | null | undefined = $derived(
		this.ollama.data === undefined
			? undefined
			: this.ollama.status === 'pending'
				? null
				: this.ollama.status === 'success' && this.ollama.data !== null,
	);

	/**
	 * Convenience accessor for websocket availability.
	 * `undefined` means uninitialized, `null` means loading/checking.
	 * boolean indicates if the socket is actively connected.
	 */
	readonly websocket_available: boolean | null | undefined = $derived(
		this.websocket.data === undefined
			? undefined
			: this.websocket.status === 'pending'
				? null
				: this.websocket.status === 'success',
	);

	/**
	 * Convenience accessor for filesystem availability.
	 * `undefined` means uninitialized, `null` means loading/checking.
	 * boolean indicates if filesystem is available.
	 */
	readonly filesystem_available: boolean | null | undefined = $derived(
		this.filesystem.data === undefined
			? undefined
			: this.filesystem.status === 'pending'
				? null
				: this.filesystem.status === 'success',
	);

	/**
	 * Latest Ollama model list response, if available.
	 */
	readonly ollama_models: Array<{
		name: string;
		size: number;
		model_response: Ollama_List_Response_Item;
	}> = $derived(
		this.app.ollama.models_downloaded
			.filter((m) => !!m.ollama_list_response_item)
			.map((m) => ({
				name: m.name,
				size: Math.round((m.filesize ?? 0) * 1024), // Convert GB back to MB for compatibility
				model_response: m.ollama_list_response_item!,
			})),
	);

	constructor(options: Cell_Options<typeof Capabilities_Json>) {
		super(Capabilities_Json, options);
	}

	/**
	 * Check Server availability only if it hasn't been checked before.
	 * (when status is 'initial')
	 */
	async init_backend_check(): Promise<void> {
		if (this.backend.status !== 'initial') {
			return;
		}
		await this.app.api.ping();
	}

	/**
	 * Check Ollama availability only if it hasn't been checked before.
	 * (when status is 'initial')
	 */
	async init_ollama_check(): Promise<void> {
		if (this.ollama.status !== 'initial') {
			return;
		}
		await this.check_ollama();
	}

	/**
	 * Check Ollama availability by connecting to its API.
	 * @returns A promise that resolves when the check is complete
	 */
	async check_ollama(): Promise<void> {
		// Simply delegate to app.ollama.refresh()
		// The derived state will automatically update based on ollama's state
		try {
			await this.app.ollama.refresh();
		} catch (error) {
			console.error('failed to check Ollama:', error);
			// Error handling is done in the ollama class itself
		}
	}

	// TODO refactor maybe to a `Pings` class
	handle_sent_ping(request_id: Jsonrpc_Request_Id): void {
		console.log(`[capabilities] [handle_sent_ping] request_id`, request_id);
		// Create a new pending ping
		const new_ping: Ping_Data = {
			ping_id: request_id,
			completed: false,
			sent_time: Date.now(),
			received_time: null,
			round_trip_time: null,
		};

		// Add the new ping to the start of the array
		this.pings = [new_ping, ...this.pings.slice(0, PING_HISTORY_MAX - 1)];

		// TODO @many maybe refactor to middleware or more sophisticated hooks? is spread across 3 methods called from 2 mutations
		// Reset the backend state only if it hasn't connected yet, to avoid flickering
		this.backend = {
			name: 'backend',
			data: null,
			status: 'pending',
			message_id: request_id,
			error_message: null,
			updated: Date.now(),
		};
	}

	// TODO @many refactor mutations
	handle_received_ping(ping_id: Jsonrpc_Request_Id): void {
		console.log(`[capabilities] [handle_received_ping] ping_id`, ping_id);
		const ping = this.pings.find((p) => p.ping_id === ping_id);
		// If we can't find the ping, we can safely ignore it
		if (!ping) {
			return;
		}

		const received_time = Date.now();

		ping.completed = true;
		ping.received_time = received_time;
		ping.round_trip_time = received_time - ping.sent_time;

		// TODO @many maybe refactor to middleware or more sophisticated hooks? is spread across 3 methods called from 2 mutations
		if (this.backend.message_id === ping_id) {
			this.backend = {
				name: 'backend',
				data: {
					round_trip_time: ping.round_trip_time,
				},
				status: 'success',
				message_id: ping_id,
				error_message: null,
				updated: Date.now(),
			};
		}
	}

	handle_ping_error(ping_id: Jsonrpc_Request_Id, error_message: string): void {
		console.error(`[capabilities] [handle_ping_error] ping_id`, ping_id, error_message);
		// TODO @many maybe refactor to middleware or more sophisticated hooks? is spread across 3 methods called from 2 mutations
		if (this.backend.message_id === ping_id) {
			this.backend = {
				name: 'backend',
				data: null,
				status: 'failure',
				message_id: ping_id,
				error_message,
				updated: Date.now(),
			};
		}
	}

	/**
	 * Reset just the backend capability to uninitialized state.
	 */
	reset_backend(): void {
		this.backend = {
			name: 'backend',
			data: undefined,
			status: 'initial',
			message_id: null,
			error_message: null,
			updated: null,
		};
	}

	// TODO maybe should be a method on app.ollama?
	reset_ollama(): void {
		// Reset the ollama state in app.ollama
		this.app.ollama.list_response = null;
		this.app.ollama.list_status = 'initial';
		this.app.ollama.list_error = null;
		this.app.ollama.list_last_updated = null;
		this.app.ollama.list_round_trip_time = null;
		this.app.ollama.ps_response = null;
		this.app.ollama.ps_status = 'initial';
		this.app.ollama.ps_error = null;
	}
}
