import type {Model_Type} from './config_helpers.js';

export type Agent_Name = 'claude' | 'gpt' | 'gemini'; // TODO extensible

export interface Agent_Json {
	name: Agent_Name;
	icon: string;
	title: string;
	models: Record<Model_Type, string>;
	url: string;
}

export interface Agent_Options {
	data: Agent_Json;
}

export class Agent {
	name: Agent_Name = $state()!;
	icon: string = $state()!;
	title: string = $state()!;
	models: Record<Model_Type, string> = $state()!;
	url: string = $state()!;

	// TODO
	// models

	constructor(options: Agent_Options) {
		const {
			data: {name, icon, title, models, url},
		} = options;
		this.name = name;
		this.icon = icon;
		this.title = title;
		this.models = models;
		this.url = url;
	}

	toJSON(): Agent_Json {
		return {
			name: this.name,
			icon: this.icon,
			title: this.title,
			models: this.models,
			url: this.url,
		};
	}
}
