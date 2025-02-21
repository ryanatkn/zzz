import type {Flavored} from '@ryanatkn/belt/types.js';

import type {Provider_Name} from '$lib/provider.svelte.js';
import type {Ollama_Model_Info} from '$lib/ollama.js';
import type {Zzz} from '$lib/zzz.svelte.js';

export type Model_Name = Flavored<string, 'Model'>;

export interface Model_Json {
	name: string;
	provider_name: Provider_Name;
	tags: Array<string>;
	architecture?: string;
	parameter_count?: number;
	context_window?: number;
	output_token_limit?: number;
	embedding_length?: number;
	/** Size of the model file in gigabytes. */
	filesize?: number;
	cost_input?: number;
	cost_output?: number;
	training_cutoff?: string;
	ollama_model_info?: Ollama_Model_Info;
}

export interface Model_Options {
	zzz: Zzz;
	json: Model_Json;
}

export class Model {
	zzz: Zzz;

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

	constructor(options: Model_Options) {
		const {zzz, json} = options;
		this.zzz = zzz;

		this.name = json.name;
		this.provider_name = json.provider_name;
		this.tags = json.tags;
		this.architecture = json.architecture;
		this.parameter_count = json.parameter_count;
		this.context_window = json.context_window;
		this.output_token_limit = json.output_token_limit;
		this.embedding_length = json.embedding_length;
		this.filesize = json.filesize;
		this.cost_input = json.cost_input;
		this.cost_output = json.cost_output;
		this.training_cutoff = json.training_cutoff;
		this.ollama_model_info = json.ollama_model_info;
	}

	toJSON(): Model_Json {
		return {
			name: this.name,
			provider_name: this.provider_name,
			tags: this.tags,
			architecture: this.architecture,
			parameter_count: this.parameter_count,
			context_window: this.context_window,
			output_token_limit: this.output_token_limit,
			embedding_length: this.embedding_length,
			filesize: this.filesize,
			cost_input: this.cost_input,
			cost_output: this.cost_output,
			training_cutoff: this.training_cutoff,
			ollama_model_info: this.ollama_model_info,
		};
	}
}
