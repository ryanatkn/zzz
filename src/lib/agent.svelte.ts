export interface Agent_Json {
	name: string;
	title: string;
}

export interface Agent_Options {
	data: Agent_Json;
}

export class Agent {
	name: string = $state()!;
	title: string = $state()!;

	// TODO
	// models

	constructor(options: Agent_Options) {
		const {
			data: {name, title},
		} = options;
		this.name = name;
		this.title = title;
	}

	toJSON(): Agent_Json {
		return {
			name: this.name,
			title: this.title,
		};
	}
}
