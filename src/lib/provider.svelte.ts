import type {Model} from '$lib/model.svelte.js';

export type Provider_Name = 'claude' | 'chatgpt' | 'gemini'; // TODO extensible

export interface Provider_Json {
	name: Provider_Name;
	icon: string;
	title: string;
	url: string;
}

export interface Provider_Options {
	data: Provider_Json;
	all_models: Array<Model>;
}

// TODO BLOCK `Provider` is the wrong word here, more like Model_Service
export class Provider {
	name: Provider_Name = $state()!;
	icon: string = $state()!;
	title: string = $state()!;
	all_models: Array<Model> = $state()!;
	url: string = $state()!;

	models = $derived(this.all_models.filter((m) => m.provider_name === this.name));
	// TODO BLOCK this isn't a thing, each message is to an provider+model
	selected_model_name: string = $state()!;
	selected_model: Model = $derived(
		this.all_models.find((m) => m.name === this.selected_model_name)!,
	);

	constructor(options: Provider_Options) {
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

	toJSON(): Provider_Json {
		return {
			name: this.name,
			icon: this.icon,
			title: this.title,
			url: this.url,
		};
	}
}
