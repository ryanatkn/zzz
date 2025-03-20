import {z} from 'zod';
import type {ListResponse} from 'ollama/browser';
import type {Async_Status} from '@ryanatkn/belt/async.js';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {ollama_list} from '$lib/ollama.js';
import {REQUEST_TIMEOUT, SERVER_URL} from '$lib/constants.js';

export const Capabilities_Json = Cell_Json.extend({});
export type Capabilities_Json = z.infer<typeof Capabilities_Json>;

/**
 * Generic interface for a capability with standardized status tracking
 */
export interface Capability<T> {
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
 * Data structure for Ollama capability
 */
export interface Ollama_Capability_Data {
	list_response: ListResponse | null;
}

/**
 * Data structure for Server capability
 */
export interface Server_Capability_Data {
	name: string;
	version: string;
	round_trip_time: number;
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
		data: undefined,
		status: 'initial',
		error_message: null,
		updated: null,
	});

	/**
	 * Ollama capability
	 */
	ollama: Capability<Ollama_Capability_Data | null | undefined> = $state({
		data: undefined,
		status: 'initial',
		error_message: null,
		updated: null,
	});

	/**
	 * Convenience accessor for server availability.
	 * `undefined` means uninitialized, `null` means loading/checking
	 * boolean indicates if available
	 */
	server_available: boolean | null | undefined = $derived(
		this.server.data === undefined
			? undefined
			: this.server.status === 'pending'
				? null
				: this.server.status === 'success' && this.server.data !== null,
	);

	/**
	 * Convenience accessor for ollama availability.
	 * `undefined` means uninitialized, `null` means loading/checking
	 * boolean indicates if available
	 */
	ollama_available: boolean | null | undefined = $derived(
		this.ollama.data === undefined
			? undefined
			: this.ollama.status === 'pending'
				? null
				: this.ollama.status === 'success' && this.ollama.data !== null,
	);

	/**
	 * Latest Ollama model list response, if available
	 */
	ollama_models: Array<{name: string; size: number}> = $derived(
		this.ollama.data?.list_response?.models.map((model) => ({
			name: model.name,
			size: Math.round(model.size / (1024 * 1024)), // Size in MB
		})) || [],
	);

	constructor(options: Cell_Options<typeof Capabilities_Json>) {
		super(Capabilities_Json, options);
	}

	async init_all(): Promise<void> {
		await this.init_server_check();
		await this.init_ollama_check();
	}

	/**
	 * Check Server availability only if it hasn't been checked before
	 * (when status is 'initial')
	 */
	async init_server_check(): Promise<void> {
		if (this.server.status === 'initial') {
			await this.check_server();
		}
	}

	/**
	 * Check Ollama availability only if it hasn't been checked before
	 * (when status is 'initial')
	 */
	async init_ollama_check(): Promise<void> {
		if (this.ollama.status === 'initial') {
			await this.check_ollama();
		}
	}

	/**
	 * Check Server availability by making an HTTP GET request to its ping endpoint
	 * @returns A promise that resolves when the check is complete
	 */
	async check_server(): Promise<void> {
		this.server = {
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
				data: null,
				status: 'failure',
				error_message,
				updated: Date.now(),
			};
		}
	}

	/**
	 * Reset all capabilities to uninitialized state
	 */
	reset_all(): void {
		this.reset_server();
		this.reset_ollama();
	}

	/**
	 * Reset just the server capability to uninitialized state
	 */
	reset_server(): void {
		this.server = {
			data: undefined,
			status: 'initial',
			error_message: null,
			updated: null,
		};
	}

	reset_ollama(): void {
		this.ollama = {
			data: undefined,
			status: 'initial',
			error_message: null,
			updated: null,
		};
	}
}
