import type {Model} from '$lib/model.svelte.js';

export type Agent_Name = 'claude' | 'gpt' | 'gemini'; // TODO extensible

export interface Agent_Json {
	name: Agent_Name;
	icon: string;
	title: string;
	url: string;
}

export interface Agent_Options {
	data: Agent_Json;
	all_models: Model[];
}

export class Agent {
	name: Agent_Name = $state()!;
	icon: string = $state()!;
	title: string = $state()!;
	all_models: Model[] = $state()!;
	url: string = $state()!;

	models = $derived(this.all_models.filter((m) => m.agent_name === this.name));
	selected_model_name: string = $state()!;
	selected_model: Model = $derived(
		this.all_models.find((m) => m.name === this.selected_model_name)!,
	);

	constructor(options: Agent_Options) {
		const {
			data: {name, icon, title, url},
			all_models,
		} = options;
		this.name = name;
		this.icon = icon;
		this.title = title;
		this.all_models = all_models;
		this.selected_model_name = this.models[0].name;
		this.url = url;
	}

	toJSON(): Agent_Json {
		return {
			name: this.name,
			icon: this.icon,
			title: this.title,
			url: this.url,
		};
	}
}
