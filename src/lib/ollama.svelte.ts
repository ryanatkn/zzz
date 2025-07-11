// @slop claude_sonnet_4

import {z} from 'zod';
import type {Async_Status} from '@ryanatkn/belt/async.js';
import {BROWSER, DEV} from 'esm-env';
import ollama_client from 'ollama/browser';
import {SvelteSet} from 'svelte/reactivity';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {get_datetime_now} from '$lib/zod_helpers.js';
import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';
import {
	OLLAMA_URL,
	Ollama_Show_Response,
	Ollama_List_Response,
	Ollama_Progress_Response,
	Ollama_Status_Response,
	Ollama_Ps_Response,
	Ollama_Ps_Response_Item,
	Ollama_Create_Request,
	Ollama_Pull_Request,
	Ollama_Copy_Request,
	Ollama_Delete_Request,
	Ollama_Show_Request,
	extract_parameter_count,
} from '$lib/ollama_helpers.js';
import type {Model, Model_Name} from '$lib/model.svelte.js';
import {Poller} from '$lib/poller.svelte.js';
import {create_map_by_property} from '$lib/iterable_helpers.js';

// TODO IDK about the `handle_` prefix for methods called by the action handlers, maybe rethink some things

// TODO the async methods need to be de-duped,
// returning current promises (maybe using deferred pattern),
// like checking the status in the methods

// TODO rough logging

export const Ollama_Json = Cell_Json.extend({
	host: z.string().default(OLLAMA_URL),
});
export type Ollama_Json = z.infer<typeof Ollama_Json>;
export type Ollama_Json_Input = z.input<typeof Ollama_Json>;

export interface Ollama_Options extends Cell_Options<typeof Ollama_Json> {
	client?: typeof ollama_client;
}

/**
 * Ollama client state management with simplified API.
 * Model data is stored in app.models, not here.
 */
export class Ollama extends Cell<typeof Ollama_Json> {
	client: typeof ollama_client;

	// Private serializable state
	#host: string = $state()!;

	// Runtime-only state
	list_response: Ollama_List_Response | null = $state.raw(null);
	list_status: Async_Status = $state('initial');
	list_error: string | null = $state(null);
	list_last_updated: number | null = $state(null);
	list_round_trip_time: number | null = $state(null);
	last_refreshed: string | null = $state(null);

	// PS (running models) state
	ps_response: Ollama_Ps_Response | null = $state.raw(null);
	ps_status: Async_Status = $state('initial');
	ps_error: string | null = $state(null);
	ps_polling_enabled: boolean = $state(false);

	readonly #ps_poller: Poller;

	// Pull model state
	pull_model_name: string = $state('');
	pull_insecure: boolean = $state(false);
	readonly pulling_models: SvelteSet<string> = new SvelteSet();

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
	// TODO maybe should be an id and serialized? think about this when dealing with adding routes for navigation
	manager_selected_model: Model | null = $state(null);
	manager_last_active_view: {view: string; model: Model | null} | null = $state(null);

	// UI state for actions
	show_read_actions: boolean = $state(false);

	// Getters and setters for serializable state
	get host(): string {
		return this.#host;
	}
	set host(value: string) {
		this.#host = Ollama_Json.shape.host.parse(value);
	}

	// Derived state
	readonly available: boolean = $derived(this.list_status === 'success');

	readonly actions = $derived(
		this.app.actions.items.values.filter((action) => action.method.startsWith('ollama_')),
	);
	readonly pending_actions = $derived(
		this.actions.filter((action) => action.action_event?.step === 'handling'),
	);
	readonly completed_actions = $derived(
		this.actions.filter(
			(action) => action.action_event?.step === 'handled' || action.action_event?.step === 'failed',
		),
	);
	readonly filtered_actions = $derived(
		(this.show_read_actions
			? this.actions.slice()
			: this.actions.filter(
					(action) =>
						// TODO maybe helper? is_ollama_read_action
						action.method !== 'ollama_list' &&
						action.method !== 'ollama_show' &&
						action.method !== 'ollama_ps',
				)
		).reverse(),
	);

	readonly models: Array<Model> = $derived(this.app.models.items.where('provider_name', 'ollama'));

	readonly models_downloaded = $derived(this.models.filter((m) => m.downloaded));
	readonly models_not_downloaded = $derived(this.models.filter((m) => !m.downloaded));

	readonly model_by_name: Map<Model_Name, Model> = $derived(
		create_map_by_property(this.models, 'name'),
	);

	readonly model_names: Array<Model_Name> = $derived(Array.from(this.model_by_name.keys()));

	// `ps` derived state
	readonly running_models: Array<Ollama_Ps_Response_Item> = $derived(
		this.ps_response?.models ?? [],
	);
	readonly running_model_names: Set<Model_Name> = $derived(
		new Set(this.running_models.map((m) => m.name)),
	);

	// `pull` model derived state
	readonly pull_parsed_model_name: Model_Name = $derived(this.pull_model_name.trim());
	readonly pull_already_downloaded: boolean = $derived(
		!!(
			this.pull_parsed_model_name && this.model_by_name.get(this.pull_parsed_model_name)?.downloaded
		),
	);
	readonly pull_can_pull: boolean = $derived(
		!!this.pull_parsed_model_name &&
			!this.pull_already_downloaded &&
			!this.pulling_models.has(this.pull_parsed_model_name),
	);

	pull_is_pulling(model_name: Model_Name): boolean {
		return this.pulling_models.has(model_name);
	}

	// `copy` model derived state
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

	// `create` model derived state
	readonly create_parsed_model_name: string = $derived(this.create_model_name.trim());
	readonly create_is_duplicate_name: boolean = $derived(
		!!this.create_parsed_model_name && this.model_by_name.has(this.create_parsed_model_name),
	);
	readonly create_can_create: boolean = $derived(
		!!this.create_parsed_model_name && !this.create_is_duplicate_name,
	);

	constructor(options: Ollama_Options) {
		super(Ollama_Json, options);

		this.client = options.client ?? ollama_client;

		this.#ps_poller = new Poller({
			poll_fn: () => {
				if (this.ps_polling_enabled && this.available) {
					void this.app.api.ollama_ps();
				}
			},
			immediate: true,
		});

		this.init();
	}

	override dispose(): void {
		this.#ps_poller.dispose(); // TODO maybe add a generic cell unsubscriber/dispose method collection?
		super.dispose();
	}

	/**
	 * Refresh the list of models and ps info and update the refresh timestamp.
	 */
	async refresh(): Promise<{
		list_response: Ollama_List_Response | null;
		ps_response: Ollama_Ps_Response | null;
	}> {
		const [list_response, ps_response] = await Promise.all([
			this.app.api.ollama_list(),
			this.app.api.ollama_ps(),
		]);
		this.last_refreshed = get_datetime_now();
		return {list_response, ps_response};
	}

	/**
	 * Start polling for running models status.
	 * Default interval is 10 seconds.
	 */
	start_ps_polling(options?: {immediate?: boolean; interval?: number}): void {
		if (!BROWSER || this.ps_polling_enabled) return;

		this.ps_polling_enabled = true;
		console.log('[ollama.start_ps_polling] starting ps polling');

		this.#ps_poller.start(options);
	}

	/**
	 * Stop polling for running models status.
	 */
	stop_ps_polling(): void {
		if (!BROWSER || !this.ps_polling_enabled) return;

		console.log('[ollama.stop_ps_polling] stopping ps polling');
		this.ps_polling_enabled = false;

		this.#ps_poller.stop();
	}

	/**
	 * List all models available on the Ollama server and sync with app.models.
	 */
	async handle_ollama_list(): Promise<Ollama_List_Response | null> {
		if (!BROWSER) return null;

		console.log(`[ollama.handle_ollama_list] listing from: ${this.host}`);

		this.list_status = 'pending';
		this.list_error = null;

		try {
			const start_time = Date.now();
			const response = (await this.client.list()) as unknown as Ollama_List_Response;
			const end_time = Date.now();

			console.log(
				`[ollama.handle_ollama_list] success, found ${response.models.length} models`,
				response,
			);

			// Parse to log bugs but assign data anyway to avoid breaking the UX
			if (DEV) {
				const parsed = Ollama_List_Response.safeParse(response);
				if (!parsed.success) {
					console.error(`[ollama.handle_ollama_list] failed to parse:`, parsed.error);
				}
			}

			this.list_response = response;
			this.list_status = 'success';
			this.list_last_updated = end_time;
			this.list_round_trip_time = end_time - start_time;

			// Sync with app.models
			this.#sync_models_with_list_response(response);

			return response;
		} catch (error) {
			console.error('[ollama.handle_ollama_list] failed:', error);
			const error_message = error?.message || UNKNOWN_ERROR_MESSAGE;
			this.list_response = null;
			this.list_error = error_message;
			this.list_status = 'failure';
			this.list_round_trip_time = null;

			return null;
		}
	}

	/**
	 * Get the list of currently running models.
	 */
	async handle_ollama_ps(): Promise<Ollama_Ps_Response | null> {
		if (!BROWSER) return null;

		console.log(`[ollama.handle_ollama_ps] fetching running models from: ${this.host}`);

		this.ps_status = 'pending';
		this.ps_error = null;

		try {
			const response = (await this.client.ps()) as unknown as Ollama_Ps_Response;
			console.log(
				`[ollama.handle_ollama_ps] success, found ${response.models.length} running models`,
				response,
			);

			// Parse to log bugs but assign data anyway to avoid breaking the UX
			if (DEV) {
				const parsed = Ollama_Ps_Response.safeParse(response);
				if (!parsed.success) {
					console.error(`[ollama.handle_ollama_ps] failed to parse:`, parsed.error);
				}
			}

			this.ps_response = response;
			this.ps_status = 'success';

			return response;
		} catch (error) {
			console.error('[ollama.handle_ollama_ps] failed:', error);
			const error_message = error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE;
			this.ps_error = error_message;
			this.ps_status = 'failure';

			return null;
		}
	}

	/**
	 * Get detailed information about a specific model.
	 */
	async handle_ollama_show(request: Ollama_Show_Request): Promise<Ollama_Show_Response | null> {
		if (!BROWSER) return null;

		const model = this.app.models.find_by_name(request.model);
		if (!model) {
			console.error(`[ollama.handle_ollama_show] model not found: ${request.model}`);
			return null;
		}
		if (model.provider_name !== 'ollama') {
			console.error(`[ollama.handle_ollama_show] model not an ollama model: ${request.model}`);
			return null;
		}

		console.log(`[ollama.handle_ollama_show] showing details for: ${request.model}`);

		// Update loading state on the model
		model.ollama_show_response_loading = true;
		model.ollama_show_response_error = undefined;

		try {
			const response = (await this.client.show(request)) as unknown as Ollama_Show_Response;
			console.log(`[ollama.handle_ollama_show] success for: ${request.model}`, response);

			// Parse to log bugs but assign data anyway to avoid breaking the UX
			if (DEV) {
				const parsed = Ollama_Show_Response.safeParse(response);
				if (!parsed.success) {
					console.error(
						`[ollama.handle_ollama_show] failed to parse for ${request.model}:`,
						parsed.error,
					);
				}
			}

			// Update model with details
			// TODO maybe remove to avoid bloat? or is it needed for something
			response.tensors = undefined;
			model.ollama_show_response = response;
			model.ollama_show_response_loaded = true;
			model.ollama_show_response_loading = false;

			return response;
		} catch (error) {
			console.error(`[ollama.handle_ollama_show] failed for ${request.model}:`, error);
			const error_message = error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE;

			model.ollama_show_response_loading = false;
			model.ollama_show_response_error = error_message;

			return null;
		}
	}

	/**
	 * Pull a model from the Ollama registry.
	 */
	async handle_ollama_pull(
		request: Ollama_Pull_Request,
		update_progress: (progress: unknown) => void,
	): Promise<void> {
		console.log('[ollama.handle_ollama_pull] pulling:', request);

		if (!BROWSER) return;

		this.pulling_models.add(request.model);

		try {
			// TODO fix type to remove stream or something
			const response = await this.client.pull({...request, stream: true});
			console.log(`[ollama.handle_ollama_pull] streaming started for: ${request.model}`);

			for await (const progress of response) {
				// console.log(`[ollama.handle_ollama_pull] progress`, progress);
				if (DEV) {
					const parsed = Ollama_Progress_Response.safeParse(progress);
					if (!parsed.success) {
						console.error(
							`[ollama.handle_ollama_pull] failed to parse for ${request.model}:`,
							parsed.error,
						);
					}
				}

				// Update progress via callback if provided
				console.log(`progress`, progress);
				update_progress(progress);
			}

			console.log(`[ollama.handle_ollama_pull] completed`);

			// Refresh model list after successful pull
			await this.refresh();
		} catch (error) {
			console.error(`[ollama.handle_ollama_pull] failed for ${request.model}:`, error);
			throw error; // Re-throw so action event can handle the error
		} finally {
			this.pulling_models.delete(request.model);
		}
	}

	/**
	 * Delete a model from the Ollama server.
	 */
	async handle_ollama_delete(request: Ollama_Delete_Request): Promise<void> {
		console.log(`[ollama.handle_ollama_delete] deleting: ${request.model}`);

		if (!BROWSER) return;

		try {
			const response = await this.client.delete({model: request.model});
			console.log(`[ollama.handle_ollama_delete] success for: ${request.model}`, response);

			if (DEV) {
				const parsed = Ollama_Status_Response.safeParse(response);
				if (!parsed.success) {
					console.error(
						`[ollama.handle_ollama_delete] failed to parse for ${request.model}:`,
						parsed.error,
					);
				}
			}

			// Refresh model list after successful deletion
			await this.refresh();
		} catch (error) {
			console.error(`[ollama.handle_ollama_delete] failed for ${request.model}:`, error);
			throw error;
		}
	}

	/**
	 * Copy a model to a new name.
	 */
	async handle_ollama_copy(request: Ollama_Copy_Request): Promise<void> {
		const {source, destination} = request;
		console.log(`[ollama.handle_ollama_copy] copying: ${source} → ${destination}`);

		if (!BROWSER) return;

		// Check if destination model already exists
		if (this.model_by_name.has(destination)) {
			const error_message = `Model "${destination}" already exists`;
			console.error(`[ollama.handle_ollama_copy] ${error_message}`);
			throw new Error(error_message);
		}

		try {
			const response = await this.client.copy(request);
			console.log(`[ollama.handle_ollama_copy] success: ${source} → ${destination}`, response);

			if (DEV) {
				const parsed = Ollama_Status_Response.safeParse(response);
				if (!parsed.success) {
					console.error(
						`[ollama.handle_ollama_copy] failed to parse for ${source} → ${destination}:`,
						parsed.error,
					);
				}
			}

			// Refresh model list after successful copy
			await this.refresh();
		} catch (error) {
			console.error(`[ollama.handle_ollama_copy] failed for ${source} → ${destination}:`, error);
			throw error;
		}
	}

	/**
	 * Create a new model with custom configuration.
	 */
	async handle_ollama_create(
		request: Ollama_Create_Request,
		// update_progress?: Progress_Update_Callback,
	): Promise<void> {
		console.log(`[ollama.handle_ollama_create] creating: ${request.model}`);

		if (!BROWSER) return;

		// Check if model already exists
		if (this.model_by_name.has(request.model)) {
			const error_message = `Model "${request.model}" already exists`;
			console.error(`[ollama.handle_ollama_create] ${error_message}`);
			throw new Error(error_message);
		}

		try {
			// TODO stream so we get progress updates
			const response = await this.client.create({...request, stream: false});
			console.log(`[ollama.handle_ollama_create] success for: ${request.model}`, response);

			if (DEV) {
				const parsed = Ollama_Progress_Response.safeParse(response);
				if (!parsed.success) {
					console.error(
						`[ollama.handle_ollama_create] failed to parse for ${request.model}:`,
						parsed.error,
					);
				}
			}

			// Refresh model list after successful creation
			await this.refresh();
		} catch (error) {
			console.error(`[ollama.handle_ollama_create] failed for ${request.model}:`, error);
			throw error;
		}
	}

	/**
	 * Clear details for a specific model.
	 */
	clear_model_details(model: Model): void {
		if (model.provider_name === 'ollama') {
			model.ollama_show_response = undefined;
			model.ollama_show_response_loaded = false;
			model.ollama_show_response_error = undefined;
		}
	}

	/**
	 * Clear all model details.
	 */
	clear_all_model_details(): void {
		for (const model of this.models) {
			this.clear_model_details(model);
		}
	}

	// TODO this `handle` method pattern should maybe be in `frontend_action_handlers.ts`
	/**
	 * Submit pull model form.
	 */
	async pull(): Promise<void> {
		if (!this.pull_can_pull) return;

		try {
			// TODO makes me think we should mark methods that use the API, maybe just in the generated reference docs
			await this.app.api.ollama_pull({
				model: this.pull_parsed_model_name,
				insecure: this.pull_insecure,
			});
			this.pull_model_name = '';
			this.pull_insecure = false;
		} catch (error) {
			console.error('[ollama.pull] failed:', error);
		}
	}

	/**
	 * Submit copy model form.
	 */
	async copy(): Promise<void> {
		if (!this.copy_destination_model_changed) return;

		this.copy_is_copying = true;
		try {
			await this.app.api.ollama_copy({
				source: this.copy_parsed_source_model,
				destination: this.copy_parsed_destination_model,
			});
			this.copy_source_model = '';
			this.copy_destination_model = '';
		} catch (error) {
			console.error('[ollama.copy] failed:', error);
		} finally {
			this.copy_is_copying = false;
		}
	}

	/**
	 * Submit create model form.
	 */
	async create(): Promise<void> {
		if (!this.create_can_create) return;

		this.create_is_creating = true;
		try {
			await this.app.api.ollama_create({
				model: this.create_parsed_model_name,
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
			console.error('[ollama.handle_create] failed:', error);
		} finally {
			this.create_is_creating = false;
		}
	}

	/**
	 * Submit delete model form.
	 */
	async delete(model_name: string): Promise<void> {
		console.log(`[ollama.delete_model] deleting from manager: ${model_name}`);
		await this.app.api.ollama_delete({model: model_name});
		// Clear selection if the deleted model was selected
		if (this.manager_selected_model?.name === model_name) {
			this.set_manager_view('configure', null);
		}
	}

	/**
	 * Select model in manager.
	 */
	async select(model: Model): Promise<void> {
		this.set_manager_view('model', model);
		// Auto-load details if not already loaded
		if (model.needs_ollama_details) {
			await this.app.api.ollama_show({model: model.name});
		}
	}

	/**
	 * Handle close form in manager.
	 */
	close_form(): void {
		this.set_manager_view('configure', null);
	}

	/**
	 * Set the manager view and optionally the selected model.
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
	 * Navigate back to the last active view.
	 */
	manager_back_to_last_view(): void {
		if (this.manager_last_active_view) {
			const view_to_restore = this.manager_last_active_view;
			this.manager_last_active_view = null; // Clear history
			this.manager_selected_view = view_to_restore.view as typeof this.manager_selected_view;
			this.manager_selected_model = view_to_restore.model;
		}
	}

	// Private methods

	/**
	 * Sync the list response with app.models.
	 */
	#sync_models_with_list_response(response: Ollama_List_Response): void {
		// Get current ollama models for comparison
		const existing_models = new Map(this.models.map((m) => [m.name, m]));

		// Update or add models
		for (const m of response.models) {
			const existing = existing_models.get(m.name);

			if (existing) {
				// Update existing model with fresh data
				existing.filesize = m.size / (1024 * 1024 * 1024); // Convert bytes to GB
				existing.ollama_list_response_item = m;
				existing_models.delete(m.name);
			} else {
				// Add new model
				this.app.models.add({
					name: m.name,
					provider_name: 'ollama',
					filesize: m.size / (1024 * 1024 * 1024), // Convert bytes to GB
					// Extract some info from details if available
					parameter_count: extract_parameter_count(m.details?.parameter_size),
					architecture: m.details?.family,
					ollama_list_response_item: m,
				});
			}
		}

		// Remove models that no longer exist in Ollama
		for (const removed_model of existing_models.values()) {
			removed_model.ollama_list_response_item = undefined;
			this.clear_model_details(removed_model);
			// We keep the model but the state will show as not downloaded
		}
	}
}
