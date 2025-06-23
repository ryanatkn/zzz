import {z} from 'zod';
import {SvelteMap} from 'svelte/reactivity';
import type {Async_Status} from '@ryanatkn/belt/async.js';
import {BROWSER} from 'esm-env';
import ollama, {type ListResponse, type ModelResponse, type ShowResponse} from 'ollama/browser';
import {formatDistance} from 'date-fns';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {create_uuid, type Uuid, get_datetime_now} from '$lib/zod_helpers.js';
import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';

export const Ollama_Json = Cell_Json.extend({
	host: z.string().default('http://127.0.0.1:11434'),
});
export type Ollama_Json = z.infer<typeof Ollama_Json>;
export type Ollama_Json_Input = z.input<typeof Ollama_Json>;

export interface Ollama_Options extends Cell_Options<typeof Ollama_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

/**
 * Cell class for tracking individual Ollama operations
 */
export const Ollama_Operation_Json = Cell_Json.extend({
	type: z.enum(['pull', 'create', 'delete', 'copy', 'show', 'list']),
	status: z.enum(['initial', 'pending', 'success', 'failure']).default('initial'),
	model: z.string().optional(),
	progress: z.number().min(0).max(100).optional(),
	error_message: z.string().optional(),
	result: z.any().optional(),
	operation_id: z.string().optional(),
});
export type Ollama_Operation_Json = z.infer<typeof Ollama_Operation_Json>;
export type Ollama_Operation_Json_Input = z.input<typeof Ollama_Operation_Json>;

export interface Ollama_Operation_Options extends Cell_Options<typeof Ollama_Operation_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Ollama_Operation extends Cell<typeof Ollama_Operation_Json> {
	type: 'pull' | 'create' | 'delete' | 'copy' | 'show' | 'list' = $state()!;
	status: Async_Status = $state()!;
	model: string | undefined = $state();
	progress: number | undefined = $state();
	error_message: string | undefined = $state();
	result: any = $state();
	operation_id: string | undefined = $state();

	constructor(options: Ollama_Operation_Options) {
		super(Ollama_Operation_Json, options);
		this.init();
	}

	complete_success(result?: any): void {
		this.status = 'success';
		this.result = result;
		this.updated = get_datetime_now();
	}

	complete_failure(error_message: string): void {
		this.status = 'failure';
		this.error_message = error_message;
		this.updated = get_datetime_now();
	}

	update_progress(progress: number): void {
		this.progress = Math.max(0, Math.min(100, progress));
		this.updated = get_datetime_now();
	}
}

/**
 * Cell class for model details with caching
 */
export const Ollama_Model_Detail_Json = Cell_Json.extend({
	model_name: z.string(),
	model_response: z.any().optional(),
	show_response: z.any().optional(),
	show_status: z.enum(['initial', 'pending', 'success', 'failure']).default('initial'),
	show_error: z.string().optional(),
	last_updated: z.number(),
});
export type Ollama_Model_Detail_Json = z.infer<typeof Ollama_Model_Detail_Json>;
export type Ollama_Model_Detail_Json_Input = z.input<typeof Ollama_Model_Detail_Json>;

export interface Ollama_Model_Detail_Options // eslint-disable-line @typescript-eslint/no-empty-object-type
	extends Cell_Options<typeof Ollama_Model_Detail_Json> {}

export class Ollama_Model_Detail extends Cell<typeof Ollama_Model_Detail_Json> {
	model_name: string = $state()!;
	model_response: ModelResponse | undefined = $state();
	show_response: ShowResponse | undefined = $state();
	show_status: Async_Status = $state()!;
	show_error: string | undefined = $state();
	last_updated: number = $state()!;

	readonly is_loading: boolean = $derived(this.show_status === 'pending');
	readonly has_details: boolean = $derived(!!this.show_response);
	readonly has_error: boolean = $derived(this.show_status === 'failure');

	constructor(options: Ollama_Model_Detail_Options) {
		super(Ollama_Model_Detail_Json, options);
		this.init();
	}

	start_loading(): void {
		this.show_status = 'pending';
		this.show_error = undefined;
		this.last_updated = Date.now();
	}

	complete_loading(show_response: ShowResponse): void {
		this.show_response = show_response;
		this.show_status = 'success';
		this.show_error = undefined;
		this.last_updated = Date.now();
	}

	fail_loading(error_message: string): void {
		this.show_status = 'failure';
		this.show_error = error_message;
		this.last_updated = Date.now();
	}

	reset(): void {
		this.show_response = undefined;
		this.show_status = 'initial';
		this.show_error = undefined;
		this.last_updated = Date.now();
	}
}

/**
 * Ollama client state management with full API coverage.
 */
export class Ollama extends Cell<typeof Ollama_Json> {
	// Private serializable state
	#host: string = $state()!;

	// Runtime-only state
	list_response: ListResponse | null = $state(null);
	list_status: Async_Status = $state('initial');
	list_error: string | null = $state(null);
	list_last_updated: number | null = $state(null);
	last_refreshed: string | null = $state(null);

	last_refreshed_from_now = $derived(
		this.last_refreshed &&
			formatDistance(this.last_refreshed, this.app.time.now_ms, {addSuffix: true}),
	);

	// Operations tracking using Cell instances
	operations: SvelteMap<Uuid, Ollama_Operation> = new SvelteMap();

	// Model details cache using Cell instances
	model_details: SvelteMap<string, Ollama_Model_Detail> = new SvelteMap();

	// Getters and setters for serializable state
	get host(): string {
		return this.#host;
	}
	set host(value: string) {
		this.#host = Ollama_Json.shape.host.parse(value);
		this.#update_ollama_config();
	}

	// Derived state
	readonly available: boolean = $derived(this.list_status === 'success');
	readonly models_count: number = $derived(this.list_response?.models.length ?? 0);
	readonly pending_operations: Array<Ollama_Operation> = $derived(
		Array.from(this.operations.values()).filter((op) => op.status === 'pending'),
	);
	readonly completed_operations: Array<Ollama_Operation> = $derived(
		Array.from(this.operations.values()).filter(
			(op) => op.status === 'success' || op.status === 'failure',
		),
	);

	readonly models_with_details: Array<Ollama_Model_Detail> = $derived.by(() => {
		if (!this.list_response?.models) return [];

		return this.list_response.models
			.map((model) => this.model_details.get(model.name))
			.filter(Boolean) as Array<Ollama_Model_Detail>;
	});

	constructor(options: Ollama_Options) {
		super(Ollama_Json, options);
		this.init();
		this.#update_ollama_config();
	}

	/**
	 * Refresh the list of models and update timestamps.
	 */
	async refresh(): Promise<ListResponse | null> {
		const result = await this.list_models();
		this.last_refreshed = get_datetime_now();
		return result;
	}

	/**
	 * List all models available on the Ollama server.
	 */
	async list_models(): Promise<ListResponse | null> {
		if (!BROWSER) return null;

		console.log(`[ollama] listing models from: ${this.host}`);

		this.list_status = 'pending';
		this.list_error = null;

		try {
			const response = await ollama.list();
			console.log(`[ollama] list models success, found ${response.models.length} models`, response);

			this.list_response = response;
			this.list_status = 'success';
			this.list_last_updated = Date.now();

			// Ensure model details exist for all models and update existing ones
			for (const model of response.models) {
				let detail = this.model_details.get(model.name);
				if (!detail) {
					detail = new Ollama_Model_Detail({
						app: this.app,
						json: {
							model_name: model.name,
							last_updated: Date.now(),
						},
					});
					this.model_details.set(model.name, detail);
				}
				// Update the model response for both new and existing details
				detail.model_response = model;
			}

			return response;
		} catch (error) {
			console.error('[ollama] failed to list models:', error);
			this.list_error = error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE;
			this.list_status = 'failure';
			return null;
		}
	}

	/**
	 * Get detailed information about a specific model.
	 */
	async show_model(model_name: string): Promise<ShowResponse | null> {
		if (!BROWSER) return null;

		console.log(`[ollama] showing model details for: ${model_name}`);

		const operation_id = create_uuid();
		const operation = new Ollama_Operation({
			app: this.app,
			json: {
				type: 'show',
				status: 'pending',
				model: model_name,
				operation_id,
			},
		});

		this.operations.set(operation_id, operation);

		let detail = this.model_details.get(model_name);
		if (!detail) {
			detail = new Ollama_Model_Detail({
				app: this.app,
				json: {
					model_name,
					last_updated: Date.now(),
				},
			});
			this.model_details.set(model_name, detail);
		}

		detail.start_loading();

		try {
			const response = await ollama.show({model: model_name});
			console.log(`[ollama] show model success for: ${model_name}`, response);

			detail.complete_loading(response);
			operation.complete_success(response);

			return response;
		} catch (error) {
			console.error(`[ollama] failed to show model ${model_name}:`, error);
			const error_message = error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE;

			detail.fail_loading(error_message);
			operation.complete_failure(error_message);

			return null;
		}
	}

	/**
	 * Pull a model from the Ollama registry.
	 */
	async pull_model(model_name: string, insecure = false): Promise<Uuid> {
		console.log(`[ollama] pulling model: ${model_name}, insecure: ${insecure}`);

		const operation_id = create_uuid();
		const operation = new Ollama_Operation({
			app: this.app,
			json: {
				type: 'pull',
				status: 'pending',
				model: model_name,
				progress: 0,
			},
		});

		this.operations.set(operation_id, operation);

		if (!BROWSER) return operation_id;

		try {
			const response = await ollama.pull({model: model_name, insecure, stream: false});
			console.log(`[ollama] pull model success for: ${model_name}`, response);

			operation.complete_success(response);

			// Refresh model list after successful pull
			await this.refresh();
		} catch (error) {
			console.error(`[ollama] failed to pull model ${model_name}:`, error);
			operation.complete_failure(error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE);
		}

		return operation_id;
	}

	/**
	 * Delete a model from the Ollama server.
	 */
	async delete_model(model_name: string): Promise<Uuid> {
		console.log(`[ollama] deleting model: ${model_name}`);

		const operation_id = create_uuid();
		const operation = new Ollama_Operation({
			app: this.app,
			json: {
				type: 'delete',
				status: 'pending',
				model: model_name,
			},
		});

		this.operations.set(operation_id, operation);

		if (!BROWSER) return operation_id;

		try {
			const response = await ollama.delete({model: model_name});
			console.log(`[ollama] delete model success for: ${model_name}`, response);

			operation.complete_success(response);

			// Remove from model details cache
			this.model_details.delete(model_name);

			// Refresh model list after successful delete
			await this.refresh();
		} catch (error) {
			console.error(`[ollama] failed to delete model ${model_name}:`, error);
			operation.complete_failure(error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE);
		}

		return operation_id;
	}

	/**
	 * Copy a model to a new name.
	 */
	async copy_model(source: string, destination: string): Promise<Uuid> {
		console.log(`[ollama] copying model: ${source} → ${destination}`);

		const operation_id = create_uuid();
		const operation = new Ollama_Operation({
			app: this.app,
			json: {
				type: 'copy',
				status: 'pending',
				model: `${source} → ${destination}`,
			},
		});

		this.operations.set(operation_id, operation);

		if (!BROWSER) return operation_id;

		try {
			const response = await ollama.copy({source, destination});
			console.log(`[ollama] copy model success: ${source} → ${destination}`, response);

			operation.complete_success(response);

			// Refresh model list after successful copy
			await this.refresh();
		} catch (error) {
			console.error(`[ollama] failed to copy model ${source} → ${destination}:`, error);
			operation.complete_failure(error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE);
		}

		return operation_id;
	}

	/**
	 * Create a new model from a Modelfile.
	 */
	async create_model(name: string, from?: string, modelfile?: string): Promise<Uuid> {
		console.log(`[ollama] creating model: ${name}, from: ${from || 'none'}`);

		const operation_id = create_uuid();
		const operation = new Ollama_Operation({
			app: this.app,
			json: {
				type: 'create',
				status: 'pending',
				model: name,
			},
		});

		this.operations.set(operation_id, operation);

		if (!BROWSER) return operation_id;

		try {
			const create_request: any = {name, stream: false};
			if (from) create_request.from = from;
			if (modelfile) create_request.modelfile = modelfile;

			const response = await ollama.create(create_request);
			console.log(`[ollama] create model success for: ${name}`, response);

			operation.complete_success(response);

			// Refresh model list after successful create
			await this.refresh();
		} catch (error) {
			console.error(`[ollama] failed to create model ${name}:`, error);
			operation.complete_failure(error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE);
		}

		return operation_id;
	}

	/**
	 * Clear completed operations from the history.
	 */
	clear_completed_operations(): void {
		for (const [id, operation] of this.operations.entries()) {
			if (operation.status === 'success' || operation.status === 'failure') {
				this.operations.delete(id);
			}
		}
	}

	/**
	 * Clear all model details cache.
	 */
	clear_model_details_cache(): void {
		this.model_details.clear();
	}

	// Private methods

	#update_ollama_config(): void {
		if (!BROWSER) return;
		// Update the global ollama instance configuration
		(ollama as any).config = {host: this.host};
	}
}
