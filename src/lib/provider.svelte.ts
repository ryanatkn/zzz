import {z} from 'zod';

import type {Model} from '$lib/model.svelte.js';
import type {Zzz} from '$lib/zzz.svelte.js';

// TODO extensible?
export const Provider_Name = z.enum(['ollama', 'claude', 'chatgpt', 'gemini']);
export type Provider_Name = z.infer<typeof Provider_Name>;

export interface Provider_Json {
	name: Provider_Name;
	icon: string;
	title: string;
	url: string;
}

export interface Provider_Options {
	zzz: Zzz;
	json: Provider_Json;
}

// TODO BLOCK `Provider` is the wrong word here, more like Model_Service
export class Provider {
	zzz: Zzz;

	name: Provider_Name = $state()!;
	icon: string = $state()!;
	title: string = $state()!;
	url: string = $state()!;

	models: Array<Model> = $derived.by(() =>
		this.zzz.models.items.filter((m) => m.provider_name === this.name),
	);
	// TODO BLOCK this isn't a thing, each message is to an provider+model
	selected_model_name: string | undefined = $state();
	selected_model: Model | undefined = $derived.by(() =>
		this.zzz.models.items.find((m) => m.name === this.selected_model_name),
	);

	constructor(options: Provider_Options) {
		const {
			zzz,
			json: {name, icon, title, url},
		} = options;
		this.zzz = zzz;
		this.name = name;
		this.icon = icon;
		this.title = title;
		const selected_model = this.models[0] as Model | undefined;
		this.selected_model_name = selected_model?.name;
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
