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

	constructor(options: Model_Options) {
		const {
			zzz,
			json: {name, provider_name, tags},
		} = options;
		this.zzz = zzz;
		this.name = name;
		this.provider_name = provider_name;
		this.tags = tags;
	}

	toJSON(): Model_Json {
		return {
			name: this.name,
			provider_name: this.provider_name,
			tags: this.tags,
		};
	}
}
