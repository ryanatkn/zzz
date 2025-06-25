// @slop claude_sonnet_4

import {z} from 'zod';
import {SvelteMap} from 'svelte/reactivity';
import type {Async_Status} from '@ryanatkn/belt/async.js';
import {BROWSER} from 'esm-env';
import ollama, {
	type ListResponse,
	type ShowResponse,
	type ProgressResponse,
	type StatusResponse,
	type DeleteRequest,
	type PullRequest,
	type CreateRequest,
} from 'ollama/browser';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {create_uuid, Uuid, get_datetime_now} from '$lib/zod_helpers.js';
import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';
import {OLLAMA_URL} from '$lib/ollama_helpers.js';
import type {Model} from '$lib/model.svelte.js';

export const Ollama_Json = Cell_Json.extend({
	host: z.string().default(OLLAMA_URL),
});
export type Ollama_Json = z.infer<typeof Ollama_Json>;
export type Ollama_Json_Input = z.input<typeof Ollama_Json>;

export interface Ollama_Options extends Cell_Options<typeof Ollama_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type
// TODO all of the operations stuff should probably use Action patterns,
// could have a single Ollama action, this is a good usecase for observability

/**
 * Schema for Ollama operation types
 */
export const Ollama_Operation_Type = z.enum(['pull', 'create', 'delete', 'copy', 'show', 'list']);
export type Ollama_Operation_Type = z.infer<typeof Ollama_Operation_Type>;

/**
 * Union type for all possible operation results
 */
export type Ollama_Operation_Result =
	| {type: 'list'; data: ListResponse}
	| {type: 'show'; data: ShowResponse}
	| {type: 'pull'; data: ProgressResponse}
	| {type: 'create'; data: ProgressResponse}
	| {type: 'delete'; data: StatusResponse}
	| {type: 'copy'; data: StatusResponse};

/**
 * Cell class for tracking individual Ollama operations
 */
export const Ollama_Operation_Json = Cell_Json.extend({
	operation_id: Uuid,
	type: Ollama_Operation_Type,
	status: z.enum(['initial', 'pending', 'success', 'failure']).default('initial'),
	model: z.string().optional(),
	progress: z.number().min(0).max(100).optional(),
	error_message: z.string().optional(),
	result: z.any().optional(), // TODO use discriminated union
});
export type Ollama_Operation_Json = z.infer<typeof Ollama_Operation_Json>;
export type Ollama_Operation_Json_Input = z.input<typeof Ollama_Operation_Json>;

export interface Ollama_Operation_Options extends Cell_Options<typeof Ollama_Operation_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Ollama_Operation extends Cell<typeof Ollama_Operation_Json> {
	operation_id: Uuid = $state()!;
	type: Ollama_Operation_Type = $state()!;
	status: Async_Status = $state()!;
	model: string | undefined = $state();
	progress: number | undefined = $state();
	error_message: string | undefined = $state();
	result: Ollama_Operation_Result | null = $state(null);

	constructor(options: Ollama_Operation_Options) {
		super(Ollama_Operation_Json, options);
		this.init();
	}

	complete_success(result?: Ollama_Operation_Result): void {
		this.status = 'success';
		this.result = result || null;
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
 * Ollama client state management with simplified API.
 * Model data is stored in app.models, not here.
 */
export class Ollama extends Cell<typeof Ollama_Json> {
	// Private serializable state
	#host: string = $state()!;

	// Runtime-only state
	list_status: Async_Status = $state('initial');
	list_error: string | null = $state(null);
	list_last_updated: number | null = $state(null);
	last_refreshed: string | null = $state(null);

	// Pull model state
	pull_model_name: string = $state('');
	pull_insecure: boolean = $state(false);
	pull_is_pulling: boolean = $state(false);

	// Copy model state
	copy_source_model: string = $state('');
	copy_destination_model: string = $state('');
	copy_is_copying: boolean = $state(false);

	// Create model state
	create_model_name: string = $state('');
	create_from_model: string = $state('');
	create_system_prompt: string = $state('');
	create_template: string = $state('');
	create_is_creating: boolean = $state(false);

	// Manager view state
	manager_selected_view: 'configure' | 'model' | 'pull' | 'copy' | 'create' = $state('configure');
	manager_selected_model: Model | null = $state(null);
	manager_last_active_view: {view: string; model: Model | null} | null = $state(null);

	// Operations tracking using Cell instances
	operations: SvelteMap<Uuid, Ollama_Operation> = new SvelteMap();

	// Getters and setters for serializable state
	get host(): string {
		return this.#host;
	}
	set host(value: string) {
		this.#host = Ollama_Json.shape.host.parse(value);
	}

	// Derived state
	readonly available: boolean = $derived(this.list_status === 'success');
	readonly pending_operations: Array<Ollama_Operation> = $derived(
		Array.from(this.operations.values()).filter((op) => op.status === 'pending'),
	);
	readonly completed_operations: Array<Ollama_Operation> = $derived(
		Array.from(this.operations.values()).filter(
			(op) => op.status === 'success' || op.status === 'failure',
		),
	);

	/**
	 * Get Ollama models from app.models
	 */
	readonly models: Array<Model> = $derived(this.app.models.items.where('provider_name', 'ollama'));

	readonly models_downloaded = $derived(this.models.filter((m) => m.downloaded));
	readonly models_not_downloaded = $derived(this.models.filter((m) => !m.downloaded));

	readonly model_by_name: Map<string, Model> = $derived.by(() => {
		const map: Map<string, Model> = new Map();
		for (const model of this.models) {
			map.set(model.name, model);
		}
		return map;
	});

	readonly model_names: Array<string> = $derived(Array.from(this.model_by_name.keys()));

	// Pull model derived state
	readonly pull_parsed_model_name: string = $derived(this.pull_model_name.trim());
	readonly pull_is_duplicate_name: boolean = $derived(
		!!this.pull_parsed_model_name && this.model_by_name.has(this.pull_parsed_model_name),
	);
	readonly pull_can_pull: boolean = $derived(
		!!this.pull_parsed_model_name && !this.pull_is_duplicate_name,
	);

	// Copy model derived state
	readonly copy_parsed_source_model: string = $derived(this.copy_source_model.trim());
	readonly copy_parsed_destination_model: string = $derived(this.copy_destination_model.trim());
	readonly copy_is_duplicate_name: boolean = $derived(
		!!this.copy_parsed_destination_model &&
			this.model_by_name.has(this.copy_parsed_destination_model),
	);
	readonly copy_destination_model_changed: boolean = $derived(
		!!this.copy_parsed_source_model &&
			!!this.copy_parsed_destination_model &&
			!this.copy_is_duplicate_name,
	);

	// Create model derived state
	readonly create_parsed_model_name: string = $derived(this.create_model_name.trim());
	readonly create_is_duplicate_name: boolean = $derived(
		!!this.create_parsed_model_name && this.model_by_name.has(this.create_parsed_model_name),
	);
	readonly create_can_create: boolean = $derived(
		!!this.create_parsed_model_name && !this.create_is_duplicate_name,
	);

	constructor(options: Ollama_Options) {
		super(Ollama_Json, options);
		this.init();
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
	 * List all models available on the Ollama server and sync with app.models.
	 */
	async list_models(): Promise<ListResponse | null> {
		if (!BROWSER) return null;

		console.log(`[ollama] listing models from: ${this.host}`);

		const operation = this.#create_operation('list');

		this.list_status = 'pending';
		this.list_error = null;

		try {
			const response = await ollama.list();
			console.log(`[ollama] list models success, found ${response.models.length} models`, response);

			this.list_status = 'success';
			this.list_last_updated = Date.now();

			operation.complete_success({type: 'list', data: response});

			// Sync with app.models
			this.#sync_models_with_list_response(response);

			return response;
		} catch (error) {
			console.error('[ollama] failed to list models:', error);
			const error_message = error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE;
			this.list_error = error_message;
			this.list_status = 'failure';

			operation.complete_failure(error_message);

			return null;
		}
	}

	/**
	 * Get detailed information about a specific model.
	 */
	async show_model(model_name: string): Promise<ShowResponse | null> {
		if (!BROWSER) return null;

		const model = this.app.models.find_by_name(model_name);
		if (!model) {
			console.error(`[ollama] model not found: ${model_name}`);
			return null;
		}
		if (model.provider_name !== 'ollama') {
			console.error(`[ollama] model not an ollama model: ${model_name}`);
			return null;
		}

		console.log(`[ollama] showing model details for: ${model_name}`);

		const operation = this.#create_operation('show', {model: model_name});

		// Update loading state on the model
		model.ollama_details_loading = true;
		model.ollama_details_error = undefined;

		try {
			const response = await ollama.show({model: model_name});
			console.log(`[ollama] show model success for: ${model_name}`, response);

			// Update model with details
			model.ollama_details = {
				details: response.details,
				modelfile: response.modelfile,
				template: response.template,
				system: response.system,
				license: response.license,
				model_info: response.model_info,
				modified_at: response.modified_at as unknown as string, // TODO Ollama bug or type issue?
			};
			model.ollama_details_loaded = true;
			model.ollama_details_loading = false;

			operation.complete_success({type: 'show', data: response});

			return response;
		} catch (error) {
			console.error(`[ollama] failed to show model ${model_name}:`, error);
			const error_message = error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE;

			model.ollama_details_loading = false;
			model.ollama_details_error = error_message;

			operation.complete_failure(error_message);

			return null;
		}
	}

	/**
	 * Pull a model from the Ollama registry.
	 */
	async pull_model(model_name: string, partial: Partial<PullRequest>): Promise<Uuid> {
		const insecure = partial.insecure || false;
		console.log(`[ollama] pulling model: ${model_name}, insecure: ${insecure}`);

		const operation = this.#create_operation('pull', {model: model_name, progress: 0});

		if (!BROWSER) return operation.operation_id;

		try {
			// TODO stream so we get progress updates
			const response = await ollama.pull({...partial, insecure, model: model_name, stream: false});
			console.log(`[ollama] pull model success for: ${model_name}`, response);

			operation.complete_success({type: 'pull', data: response});

			// Refresh model list after successful pull
			await this.refresh();
		} catch (error) {
			console.error(`[ollama] failed to pull model ${model_name}:`, error);
			operation.complete_failure(error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE);
		}

		return operation.operation_id;
	}

	/**
	 * Delete a model from the Ollama server.
	 */
	async delete_model(model_name: string, partial?: Partial<DeleteRequest>): Promise<Uuid> {
		console.log(`[ollama] deleting model: ${model_name}`);

		const operation = this.#create_operation('delete', {model: model_name});

		if (!BROWSER) return operation.operation_id;

		try {
			const response = await ollama.delete({...partial, model: model_name});
			console.log(`[ollama] delete model success for: ${model_name}`, response);

			operation.complete_success({type: 'delete', data: response});

			// Remove from app.models
			this.app.models.remove_by_name(model_name);
		} catch (error) {
			console.error(`[ollama] failed to delete model ${model_name}:`, error);
			operation.complete_failure(error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE);
		}

		return operation.operation_id;
	}

	/**
	 * Copy a model to a new name.
	 */
	async copy_model(source: string, destination: string): Promise<Uuid> {
		console.log(`[ollama] copying model: ${source} → ${destination}`);

		const operation = this.#create_operation('copy', {model: `${source} → ${destination}`});

		if (!BROWSER) return operation.operation_id;

		// Check if destination model already exists
		if (this.model_by_name.has(destination)) {
			const error_message = `Model "${destination}" already exists`;
			console.error(`[ollama] ${error_message}`);
			operation.complete_failure(error_message);
			return operation.operation_id;
		}

		try {
			const response = await ollama.copy({source, destination});
			console.log(`[ollama] copy model success: ${source} → ${destination}`, response);

			operation.complete_success({type: 'copy', data: response});

			// Refresh model list after successful copy
			await this.refresh();
		} catch (error) {
			console.error(`[ollama] failed to copy model ${source} → ${destination}:`, error);
			operation.complete_failure(error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE);
		}

		return operation.operation_id;
	}

	/**
	 * Create a new model with custom configuration.
	 */
	async create_model(model_name: string, partial: Partial<CreateRequest>): Promise<Uuid> {
		console.log(`[ollama] creating model: ${model_name}`);

		const operation = this.#create_operation('create', {model: model_name, progress: 0});

		if (!BROWSER) return operation.operation_id;

		// Check if model already exists
		if (this.model_by_name.has(model_name)) {
			const error_message = `Model "${model_name}" already exists`;
			console.error(`[ollama] ${error_message}`);
			operation.complete_failure(error_message);
			return operation.operation_id;
		}

		try {
			// TODO stream so we get progress updates
			const response = await ollama.create({...partial, model: model_name, stream: false});
			console.log(`[ollama] create model success for: ${model_name}`, response);

			operation.complete_success({type: 'create', data: response});

			// Refresh model list after successful creation
			await this.refresh();
		} catch (error) {
			console.error(`[ollama] failed to create model ${model_name}:`, error);
			operation.complete_failure(error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE);
		}

		return operation.operation_id;
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
	 * Clear details for a specific model.
	 */
	clear_model_details(model_name: string): void {
		const model = this.app.models.find_by_name(model_name);
		if (model && model.provider_name === 'ollama') {
			model.ollama_details = undefined;
			model.ollama_details_loaded = false;
			model.ollama_details_error = undefined;
		}
	}

	/**
	 * Clear and refresh details for a specific model.
	 */
	async refresh_model_details(model_name: string): Promise<void> {
		this.clear_model_details(model_name);
		await this.show_model(model_name);
	}

	/**
	 * Clear all model details.
	 */
	clear_all_model_details(): void {
		for (const model of this.models) {
			model.ollama_details = undefined;
			model.ollama_details_loaded = false;
			model.ollama_details_error = undefined;
		}
	}

	/**
	 * Handle pull model form submission
	 */
	async handle_pull(): Promise<void> {
		if (!this.pull_can_pull) return;

		this.pull_is_pulling = true;
		try {
			await this.pull_model(this.pull_parsed_model_name, {insecure: this.pull_insecure});
			this.pull_model_name = '';
			this.pull_insecure = false;
		} catch (error) {
			console.error('Pull failed:', error);
		} finally {
			this.pull_is_pulling = false;
		}
	}

	/**
	 * Handle copy model form submission
	 */
	async handle_copy(): Promise<void> {
		if (!this.copy_destination_model_changed) return;

		this.copy_is_copying = true;
		try {
			await this.copy_model(this.copy_parsed_source_model, this.copy_parsed_destination_model);
			this.copy_source_model = '';
			this.copy_destination_model = '';
		} catch (error) {
			console.error('Copy failed:', error);
		} finally {
			this.copy_is_copying = false;
		}
	}

	/**
	 * Handle create model form submission
	 */
	async handle_create(): Promise<void> {
		if (!this.create_can_create) return;

		this.create_is_creating = true;
		try {
			await this.create_model(this.create_parsed_model_name, {
				from: this.create_from_model.trim() || undefined,
				system: this.create_system_prompt.trim() || undefined,
				template: this.create_template.trim() || undefined,
			});

			// Reset form
			this.create_model_name = '';
			this.create_from_model = '';
			this.create_system_prompt = '';
			this.create_template = '';
		} catch (error) {
			console.error('Create failed:', error);
		} finally {
			this.create_is_creating = false;
		}
	}

	/**
	 * Set the manager view and optionally the selected model
	 */
	set_manager_view(view: typeof this.manager_selected_view, model?: Model | null): void {
		// Store the previous view as the last active view if it's not 'configure'
		if (this.manager_selected_view !== 'configure' && this.manager_selected_view !== view) {
			this.manager_last_active_view = {
				view: this.manager_selected_view,
				model: this.manager_selected_model,
			};
		}
		this.manager_selected_view = view;
		if (model !== undefined) {
			this.manager_selected_model = model;
		}
	}

	/**
	 * Navigate back to the last active view
	 */
	manager_back_to_last_view(): void {
		if (this.manager_last_active_view) {
			const view_to_restore = this.manager_last_active_view;
			this.manager_last_active_view = null; // Clear history
			this.manager_selected_view = view_to_restore.view as typeof this.manager_selected_view;
			this.manager_selected_model = view_to_restore.model;
		}
	}

	/**
	 * Handle delete model from manager
	 */
	async handle_delete_model(model_name: string): Promise<void> {
		console.log(`[ollama] deleting model from manager: ${model_name}`);
		await this.delete_model(model_name);
		// Clear selection if the deleted model was selected
		if (this.manager_selected_model?.name === model_name) {
			this.set_manager_view('configure', null);
		}
	}

	/**
	 * Handle select model in manager
	 */
	async handle_select_model(model: Model): Promise<void> {
		this.set_manager_view('model', model);
		// Auto-load details if not already loaded
		if (model.needs_ollama_details) {
			await this.show_model(model.name);
		}
	}

	/**
	 * Handle close form in manager
	 */
	handle_close_form(): void {
		this.set_manager_view('configure', null);
	}

	// Private methods

	#create_operation(
		type: Ollama_Operation_Type,
		options?: Partial<Ollama_Operation_Json_Input>,
	): Ollama_Operation {
		const operation_id = create_uuid();
		const operation = new Ollama_Operation({
			app: this.app,
			json: {
				type,
				status: 'pending',
				operation_id,
				...options,
			},
		});

		this.operations.set(operation_id, operation);
		return operation;
	}

	/**
	 * Sync the list response with app.models
	 */
	#sync_models_with_list_response(response: ListResponse): void {
		// Get current ollama models for comparison
		const existing_models = new Map(this.models.map((m) => [m.name, m]));

		// Update or add models
		for (const model_response of response.models) {
			const existing = existing_models.get(model_response.name);

			if (existing) {
				// Update existing model with fresh data
				existing.filesize = model_response.size / (1024 * 1024 * 1024); // Convert bytes to GB
				existing.ollama_list_data = {
					name: model_response.name,
					modified_at: model_response.modified_at as unknown as string, // TODO Ollama bug? or type issue,
					size: model_response.size,
					digest: model_response.digest,
					details: model_response.details,
				};
				existing_models.delete(model_response.name);
			} else {
				// Add new model
				this.app.models.add({
					name: model_response.name,
					provider_name: 'ollama',
					filesize: model_response.size / (1024 * 1024 * 1024), // Convert bytes to GB
					// Extract some info from details if available
					parameter_count: this.#extract_parameter_count(model_response.details.parameter_size),
					architecture: model_response.details.family,
					ollama_list_data: {
						name: model_response.name,
						modified_at: model_response.modified_at as unknown as string, // TODO Ollama bug? or type issue,
						size: model_response.size,
						digest: model_response.digest,
						details: model_response.details,
					},
				});
			}
		}

		// Remove models that no longer exist in Ollama
		for (const removed_model of existing_models.values()) {
			removed_model.ollama_list_data = undefined;
			removed_model.ollama_details = undefined;
		}
	}

	/**
	 * Extract parameter count from parameter size string like "7B", "13B", etc.
	 */
	#extract_parameter_count(parameter_size: string | undefined): number | undefined {
		if (!parameter_size) return undefined;
		const match = /^(\d+(?:\.\d+)?)[BM]?$/i.exec(parameter_size);
		if (!match) return undefined;
		const value = parseFloat(match[1]);
		// If it ends with M, convert to billions
		if (parameter_size.toUpperCase().endsWith('M')) {
			return value / 1000;
		}
		return value;
	}
}
