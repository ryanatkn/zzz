import {z} from 'zod';
import type {ListResponse} from 'ollama/browser';
import type {Async_Status} from '@ryanatkn/belt/async.js';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {ollama_list} from '$lib/ollama.js';
import {REQUEST_TIMEOUT, SERVER_URL} from '$lib/constants.js';
import {Uuid} from '$lib/zod_helpers.js';
import type {Zzz_Dir} from '$lib/diskfile_types.js';
import {Action_Ping, type Action_Pong} from '$lib/action_types.js';

// TODO hacky/hardcoded for now, this should be an extensible system, the point is to give users a good interface to the concept of capabilities

// Maximum number of ping records to keep
export const PING_HISTORY_MAX = 6;

/**
 * Data structure for ping measurements.
 */
export interface Ping_Data {
	ping_id: Uuid;
	completed: boolean;
	sent_time: number;
	received_time: number | null;
	round_trip_time: number | null;
}

// TODO which state?
export const Capabilities_Json = Cell_Json.extend({});
export type Capabilities_Json = z.infer<typeof Capabilities_Json>;
export type Capabilities_Json_Input = z.input<typeof Capabilities_Json>;

/**
 * Generic interface for a capability with standardized status tracking.
 */
export interface Capability<T> {
	/** The capability name */
	name: string;
	/** The capability's status: undefined=not initialized, null=checking, otherwise available or not */
	data: T;
	/** Async status tracking the connection/check state */
	status: Async_Status;
	/** Error message if any */
	error_message: string | null;
	/** Timestamp when the capability was last checked */
	updated: number | null;
}

/**
 * Data structure for Ollama capability.
 */
export interface Ollama_Capability_Data {
	list_response: ListResponse | null;
}

/**
 * Data structure for Server capability.
 */
export interface Server_Capability_Data {
	name: string;
	version: string;
	round_trip_time: number;
}

/**
 * Data structure for WebSocket capability.
 */
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

/**
 * Data structure for Filesystem capability.
 */
export interface Filesystem_Capability_Data {
	zzz_dir: Zzz_Dir | null | undefined;
	zzz_dir_parent: string | null | undefined;
}

/**
 * A class that encapsulates system capabilities detection and management.
 * This is NOT generic or extensible - it contains hardcoded logic for
 * all capabilities the system supports.
 */
export class Capabilities extends Cell<typeof Capabilities_Json> {
	/**
	 * Server capability
	 */
	server: Capability<Server_Capability_Data | null | undefined> = $state({
		name: 'server',
		data: undefined,
		status: 'initial',
		error_message: null,
		updated: null,
	});

	/**
	 * Ollama capability.
	 */
	ollama: Capability<Ollama_Capability_Data | null | undefined> = $state({
		name: 'ollama',
		data: undefined,
		status: 'initial',
		error_message: null,
		updated: null,
	});

	/**
	 * WebSocket capability that derives its state from the socket.
	 */
	readonly websocket: Capability<Websocket_Capability_Data | null | undefined> = $derived.by(() => {
		// Map socket status to capability status, but consider connection state
		const {socket} = this.zzz;
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
			error_message: null, // Socket doesn't expose error messages directly
			updated: data?.last_connect_time ?? null,
		};
	});

	/**
	 * Filesystem capability that derives its state from the zzz_dir.
	 */
	readonly filesystem: Capability<Filesystem_Capability_Data | null | undefined> = $derived.by(
		() => {
			// Derive status based on zzz_dir value
			const {zzz_dir, zzz_dir_parent} = this.zzz;
			let status: Async_Status;

			if (zzz_dir === undefined) {
				status = 'initial';
			} else if (zzz_dir === null) {
				status = 'pending';
			} else if (zzz_dir === '') {
				status = 'failure';
			} else {
				status = 'success';
			}

			// Filesystem is available if we have a valid zzz_dir
			const data = status === 'success' ? {zzz_dir, zzz_dir_parent} : undefined;

			return {
				name: 'filesystem',
				data,
				status,
				error_message: null,
				updated: Date.now(),
			};
		},
	);

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
	 * Convenience accessor for server availability.
	 * `undefined` means uninitialized, `null` means loading/checking.
	 * boolean indicates if available.
	 */
	readonly server_available: boolean | null | undefined = $derived(
		this.server.data === undefined
			? undefined
			: this.server.status === 'pending'
				? null
				: this.server.status === 'success' && this.server.data !== null,
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
	readonly ollama_models: Array<{name: string; size: number}> = $derived(
		this.ollama.data?.list_response?.models.map((model) => ({
			name: model.name,
			size: Math.round(model.size / (1024 * 1024)), // Size in MB
		})) || [],
	);

	constructor(options: Cell_Options<typeof Capabilities_Json>) {
		super(Capabilities_Json, options);
	}

	/**
	 * Check Server availability only if it hasn't been checked before.
	 * (when status is 'initial')
	 */
	async init_server_check(): Promise<void> {
		if (this.server.status === 'initial') {
			await this.check_server();
		}
	}

	/**
	 * Check Ollama availability only if it hasn't been checked before.
	 * (when status is 'initial')
	 */
	async init_ollama_check(): Promise<void> {
		if (this.ollama.status === 'initial') {
			await this.check_ollama();
		}
	}

	// TODO replace this with an action once the system is more developed, just manually pinging here
	/**
	 * Check Server availability by making an HTTP GET request to its ping endpoint.
	 * @returns A promise that resolves when the check is complete
	 */
	async check_server(): Promise<void> {
		this.server = {
			name: 'server',
			data: null,
			status: 'pending',
			error_message: null,
			updated: Date.now(),
		};

		const server_api_url = SERVER_URL + '/api/ping';

		let error_message: string | undefined;
		let timeout_id;

		try {
			// Track request start time
			const start_time = Date.now();

			// Make the request with a timeout
			const controller = new AbortController();
			timeout_id = setTimeout(() => controller.abort(), REQUEST_TIMEOUT);

			const response = await fetch(server_api_url, {
				signal: controller.signal,
				method: 'GET',
				headers: {Accept: 'application/json'},
			});

			clearTimeout(timeout_id);

			if (response.ok) {
				const data = await response.json();

				// Note: we're not requiring a status field in the response
				// since the server.ts implementation doesn't include it
				this.server = {
					name: 'server',
					data: {
						name: data.name,
						version: data.version,
						round_trip_time: Date.now() - start_time,
					},
					status: 'success',
					error_message: null,
					updated: Date.now(),
				};
			} else {
				error_message = `Server responded with status ${response.status}: ${response.statusText}`;
			}
		} catch (err) {
			clearTimeout(timeout_id);

			console.error('Failed to connect to server:', err);
			if (err instanceof DOMException && err.name === 'AbortError') {
				error_message = 'Request timed out';
			} else {
				error_message = err instanceof Error ? err.message : 'Unknown error connecting to server';
			}
		}

		if (error_message) {
			this.server = {
				name: 'server',
				data: null,
				status: 'failure',
				error_message,
				updated: Date.now(),
			};
		}
	}

	/**
	 * Check Ollama availability by connecting to its API
	 * @returns A promise that resolves when the check is complete
	 */
	async check_ollama(): Promise<void> {
		this.ollama = {
			name: 'ollama',
			data: null,
			status: 'pending',
			error_message: null,
			updated: Date.now(),
		};

		let error_message: string | undefined;

		try {
			// Check if Ollama API is available by getting the list of models
			const list_response = await ollama_list();

			// Set the capability data
			if (list_response) {
				this.ollama = {
					name: 'ollama',
					data: {list_response},
					status: 'success',
					error_message: null,
					updated: Date.now(),
				};
			} else {
				error_message = 'No response from Ollama API';
			}
		} catch (err) {
			console.error('Failed to connect to Ollama API:', err);
			error_message = err instanceof Error ? err.message : 'Unknown error connecting to Ollama';
		}

		if (error_message) {
			this.ollama = {
				name: 'ollama',
				data: null,
				status: 'failure',
				error_message,
				updated: Date.now(),
			};
		}
	}

	/**
	 * Sends a ping to the server over websocket.
	 * @returns The UUID of the ping message
	 */
	send_ping(): Uuid {
		const ping = Action_Ping.parse(EMPTY_OBJECT);
		const ping_id = ping.id;

		// Create a new pending ping
		const new_ping: Ping_Data = {
			ping_id,
			completed: false,
			sent_time: Date.now(),
			received_time: null,
			round_trip_time: null,
		};

		// Add the new ping to the start of the array
		this.pings = [new_ping, ...this.pings.slice(0, PING_HISTORY_MAX - 1)];

		// Send the ping message via the messaging system
		this.zzz.actions.send(ping);

		return ping_id;
	}

	/**
	 * Handle a pong response from the server.
	 * @param pong The pong message received from the server
	 */
	receive_pong(pong: Action_Pong): void {
		const received_time = Date.now();
		const ping_index = this.pings.findIndex((p) => p.ping_id === pong.ping_id);
		// If we found the ping, update it
		if (ping_index !== -1) {
			const ping = this.pings[ping_index];
			ping.completed = true;
			ping.received_time = received_time;
			ping.round_trip_time = received_time - ping.sent_time;
		}
	}

	/**
	 * Reset just the server capability to uninitialized state.
	 */
	reset_server(): void {
		this.server = {
			name: 'server',
			data: undefined,
			status: 'initial',
			error_message: null,
			updated: null,
		};
	}

	reset_ollama(): void {
		this.ollama = {
			name: 'ollama',
			data: undefined,
			status: 'initial',
			error_message: null,
			updated: null,
		};
	}
}
