import {z} from 'zod';

import {Provider_Name} from '$lib/provider_types.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import type {Ollama_Model_Info} from '$lib/ollama.js';
import {Cell_Json} from '$lib/cell_types.js';

export const Model_Name = z.string();
export type Model_Name = z.infer<typeof Model_Name>;

export const Model_Json = Cell_Json.extend({
	name: Model_Name,
	provider_name: Provider_Name,
	tags: z.array(z.string()).default(() => []),
	architecture: z.string().optional(),
	parameter_count: z.number().optional(),
	context_window: z.number().optional(),
	output_token_limit: z.number().optional(),
	embedding_length: z.number().optional(),
	filesize: z.number().optional(),
	cost_input: z.number().optional(),
	cost_output: z.number().optional(),
	training_cutoff: z.string().optional(),
	ollama_model_info: z.any().optional(),
});
export type Model_Json = z.infer<typeof Model_Json>;

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
	ollama_model_info: Ollama_Model_Info | undefined = $state();

	// TODO problem is loading status - goal is to show the loading status of the model, we need to get syncing with the API figured out
	/**
	 * For models that run locally, this is a boolean indicating if the model is downloaded.
	 * Is `undefined` for non-local models.
	 */
	downloaded: boolean | undefined = $derived(
		this.provider_name === 'ollama' ? !!this.ollama_model_info : undefined,
	);

	constructor(options: Model_Options) {
		// Pass schema and options to base constructor
		super(Model_Json, options);

		// Call init after instance properties are defined
		this.init();
	}
}
