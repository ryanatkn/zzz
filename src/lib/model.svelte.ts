import type {Flavored} from '@ryanatkn/belt/types.js';

import type {Agent_Name} from '$lib/agent.svelte.js';

export type Model_Name = Flavored<string, 'Model'>;

export interface Model_Json {
	name: string;
	agent_name: Agent_Name;
	tags: string[];
}

export interface Model_Options {
	data: Model_Json;
}

export class Model {
	name: Model_Name = $state()!;
	agent_name: Agent_Name = $state()!;
	tags: string[] = $state()!;

	constructor(options: Model_Options) {
		const {
			data: {name, agent_name, tags},
		} = options;
		this.name = name;
		this.agent_name = agent_name;
		this.tags = tags;
	}

	toJSON(): Model_Json {
		return {
			name: this.name,
			agent_name: this.agent_name,
			tags: this.tags,
		};
	}
}
