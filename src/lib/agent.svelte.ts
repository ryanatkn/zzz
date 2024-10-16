export type Agent_Name = 'claude' | 'gpt' | 'gemini'; // TODO extensible

export interface Agent_Json {
	name: Agent_Name;
	icon: string;
	title: string;
	model: string;
	url: string;
}

export interface Agent_Options {
	data: Agent_Json;
}

export class Agent {
	name: Agent_Name = $state()!;
	icon: string = $state()!;
	title: string = $state()!;
	model: string = $state()!;
	url: string = $state()!;

	// TODO
	// models

	constructor(options: Agent_Options) {
		const {
			data: {name, icon, title, model, url},
		} = options;
		this.name = name;
		this.icon = icon;
		this.title = title;
		this.model = model;
		this.url = url;
	}

	toJSON(): Agent_Json {
		return {
			name: this.name,
			icon: this.icon,
			title: this.title,
			model: this.model,
			url: this.url,
		};
	}
}
