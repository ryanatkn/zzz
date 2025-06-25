import {z} from 'zod';

import {Provider_Name} from '$lib/provider_types.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Ollama_Details, Ollama_List_Data} from '$lib/ollama_helpers.js';

export const Model_Name = z.string();
export type Model_Name = z.infer<typeof Model_Name>;

export const Model_Json = Cell_Json.extend({
	// source of truth we maintain:
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
	filesize: z.number().optional(),
	cost_input: z.number().optional(),
	cost_output: z.number().optional(),
	training_cutoff: z.string().optional(),
	// Ollama-specific fields
	ollama_list_data: Ollama_List_Data.optional(),
	ollama_details: Ollama_Details.optional(),
	ollama_details_loaded: z.boolean().default(false),
	ollama_details_loading: z.boolean().default(false),
	ollama_details_error: z.string().optional(),
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
	filesize: number | undefined = $state();
	cost_input: number | undefined = $state();
	cost_output: number | undefined = $state();
	training_cutoff: string | undefined = $state();

	// Ollama-specific state
	ollama_list_data: Ollama_List_Data | undefined = $state();
	ollama_details: Ollama_Details | undefined = $state();
	ollama_details_loaded: boolean = $state()!;
	ollama_details_loading: boolean = $state()!;
	ollama_details_error: string | undefined = $state();

	/**
	 * For models that run locally, this is a boolean indicating if the model is downloaded.
	 * Is `undefined` for non-local models.
	 */
	readonly downloaded: boolean | undefined = $derived(
		this.provider_name === 'ollama' ? !!this.ollama_list_data : undefined,
	);

	readonly context_window_formatted: string | null = $derived(
		this.context_window ? (this.context_window / 1000).toFixed(0) + 'k' : null,
	);

	/**
	 * Get the modified date from Ollama data if available.
	 */
	readonly ollama_modified_at: Date | undefined = $derived.by(() => {
		const m = this.ollama_list_data?.modified_at || this.ollama_details?.modified_at;
		return m === undefined ? undefined : typeof m === 'string' ? new Date(m) : m;
	});

	/**
	 * Check if this model needs its details loaded.
	 */
	readonly needs_ollama_details: boolean = $derived(
		this.provider_name === 'ollama' &&
			!this.ollama_details_loaded &&
			!this.ollama_details_loading &&
			!this.ollama_details_error,
	);

	constructor(options: Model_Options) {
		super(Model_Json, options);
		this.init();
	}
}

export const Model_Schema = z.instanceof(Model);
