import {z} from 'zod';
import type {ListResponse} from 'ollama/browser';
import type {Async_Status} from '@ryanatkn/belt/async.js';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {ollama_list} from '$lib/ollama.js';

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
 * A class that encapsulates system capabilities detection and management.
 * This is NOT generic or extensible - it contains hardcoded logic for
 * all capabilities the system supports.
 */
export class Capabilities extends Cell<typeof Capabilities_Json> {
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
	reset(): void {
		this.ollama = {
			data: undefined,
			status: 'initial',
			error_message: null,
			updated: null,
		};
	}
}
