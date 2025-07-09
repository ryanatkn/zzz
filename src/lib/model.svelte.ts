import {z} from 'zod';
import {base} from '$app/paths';

import {Provider_Name} from '$lib/provider_types.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Ollama_Show_Response, Ollama_List_Response_Item} from '$lib/ollama_helpers.js';
import {goto_unless_current} from '$lib/navigation_helpers.js';

export const Model_Name = z.string();
export type Model_Name = z.infer<typeof Model_Name>;

export const Model_Json = Cell_Json.extend({
	// TODO consider whether we should support one model with multiple providers,
	// or individual models per provider, currently we expect
	// `name` to be unique across providers and this should be changed,
	// I think it's like chats/prompts/etc, names should not be unique,
	// unless we think they're more like file paths? `provider_name/model_name` seems good for `path`?
	// that would make model/provider name like filenames, makes sense
	name: Model_Name,
	provider_name: Provider_Name,
	tags: z.array(z.string()).default(() => []),

	// TODO expand/improve these
	// fetched from provider APIs:
	architecture: z.string().optional(),
	parameter_count: z.number().optional(),
	context_window: z.number().optional(),
	output_token_limit: z.number().optional(),
	embedding_length: z.number().optional(),
	/** Size in gigabytes. */
	filesize: z.number().optional(),
	cost_input: z.number().optional(),
	cost_output: z.number().optional(),
	training_cutoff: z.string().optional(),
	// TODO @many maybe have a single `ollama` object?
	ollama_list_response_item: Ollama_List_Response_Item.optional(),
	ollama_show_response: Ollama_Show_Response.optional(),
	ollama_show_response_loaded: z.boolean().default(false),
	ollama_show_response_loading: z.boolean().default(false),
	ollama_show_response_error: z.string().optional(),
});
export type Model_Json = z.infer<typeof Model_Json>;
export type Model_Json_Input = z.input<typeof Model_Json>;

export interface Model_Options extends Cell_Options<typeof Model_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Model extends Cell<typeof Model_Json> {
	name: Model_Name = $state()!;
	provider_name: Provider_Name = $state()!;
	tags: Array<string> = $state()!;
	architecture: string | undefined = $state();
	parameter_count: number | undefined = $state();
	context_window: number | undefined = $state();
	output_token_limit: number | undefined = $state();
	embedding_length: number | undefined = $state();
	/** Size in gigabytes. */
	filesize: number | undefined = $state();
	cost_input: number | undefined = $state();
	cost_output: number | undefined = $state();
	training_cutoff: string | undefined = $state();

	// TODO @many maybe have a single `ollama` object?
	// in Ollamaland, list is the metadata and show is the full details
	ollama_list_response_item: Ollama_List_Response_Item | undefined = $state.raw();
	ollama_show_response: Ollama_Show_Response | undefined = $state.raw();
	ollama_show_response_loaded: boolean = $state(false);
	ollama_show_response_loading: boolean = $state(false);
	ollama_show_response_error: string | undefined = $state();

	/**
	 * For models that run locally, this is a boolean indicating if the model is downloaded.
	 * Is `undefined` for non-local models.
	 */
	readonly downloaded: boolean | undefined = $derived(
		this.provider_name === 'ollama' ? !!this.ollama_list_response_item : undefined,
	);

	readonly context_window_formatted: string | null = $derived(
		this.context_window ? (this.context_window / 1000).toFixed(0) + 'k' : null,
	);

	// TODO hacky
	/**
	 * Get the modified date from Ollama data if available.
	 */
	readonly ollama_modified_at: Date | undefined = $derived.by(() => {
		const m = this.ollama_list_response_item?.modified_at || this.ollama_show_response?.modified_at;
		return m === undefined ? undefined : typeof m === 'string' ? new Date(m) : m;
	});

	/**
	 * Check if this model needs its details loaded.
	 */
	readonly needs_ollama_details: boolean = $derived(
		this.provider_name === 'ollama' &&
			// TODO maybe separate this check for existence
			!!this.app.ollama.list_response &&
			this.app.ollama.list_response.models.some((m) => m.name === this.name) &&
			!this.ollama_show_response_loaded &&
			!this.ollama_show_response_loading &&
			!this.ollama_show_response_error,
	);

	constructor(options: Model_Options) {
		super(Model_Json, options);
		this.init();
	}

	/**
	 * Download this model. Currently only works for Ollama models.
	 */
	async navigate_to_download(): Promise<void> {
		if (this.provider_name !== 'ollama') {
			console.error(`Download not supported for provider: ${this.provider_name}`);
			return;
		}

		if (this.downloaded) {
			console.error(`Model ${this.name} is already downloaded`);
			return;
		}

		// Set the model name on the Ollama instance and navigate to the providers page
		this.app.ollama.pull_model_name = this.name;
		this.app.ollama.set_manager_view('pull');
		await goto_unless_current(`${base}/providers/ollama`);
	}

	/**
	 * Navigate to the model view. Currently only works for Ollama models.
	 */
	async navigate_to_provider_model_view(): Promise<void> {
		if (this.provider_name !== 'ollama') {
			console.error(`provider model view not supported for provider: ${this.provider_name}`);
			return;
		}

		// Set the selected model and navigate to the model view
		await Promise.all([
			// synchronously select the model but we don't care about
			// waiting for its details to load, currently part of `select`
			this.app.ollama.select(this),
			goto_unless_current(`${base}/providers/ollama`),
		]);
	}
}

export const Model_Schema = z.instanceof(Model);
