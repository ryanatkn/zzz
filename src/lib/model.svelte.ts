import type {Flavored} from '@ryanatkn/belt/types.js';

import type {Provider_Name} from '$lib/provider.svelte.js';

export type Model_Name = Flavored<string, 'Model'>;

export interface Model_Json {
	name: string;
	provider_name: Provider_Name;
	tags: Array<string>;
	parameter_count?: number;
	context_window?: number;
	output_token_limit?: number;
	cost_input?: number;
	cost_output?: number;
	training_cutoff?: string;
}

export interface Model_Options {
	data: Model_Json;
}

export class Model {
	name: Model_Name = $state()!;
	provider_name: Provider_Name = $state()!;
	tags: Array<string> = $state()!;

	constructor(options: Model_Options) {
		const {
			data: {name, provider_name, tags},
		} = options;
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
