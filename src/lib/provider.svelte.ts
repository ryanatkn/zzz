import {z} from 'zod';
import {Serializable} from '$lib/serializable.svelte.js';

import type {Model} from '$lib/model.svelte.js';
import type {Zzz} from '$lib/zzz.svelte.js';

// Define the schema here as the single source of truth
export const Provider_Name = z.enum(['ollama', 'claude', 'chatgpt', 'gemini']);
export type Provider_Name = z.infer<typeof Provider_Name>;

export const Provider_Json_Schema = z.object({
	name: Provider_Name,
	icon: z.string(),
	title: z.string(),
	url: z.string(),
});
export type Provider_Json = z.infer<typeof Provider_Json_Schema>;

export interface Provider_Options {
	zzz: Zzz;
	json?: z.input<typeof Provider_Json_Schema>;
}

// TODO BLOCK `Provider` is the wrong word here, more like Model_Service
export class Provider extends Serializable<
	z.output<typeof Provider_Json_Schema>,
	typeof Provider_Json_Schema
> {
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
		super(Provider_Json_Schema);
		this.zzz = options.zzz;

		if (options.json) {
			this.set_json(options.json);
		}

		const {
			json: {name, icon, title, url},
		} = options;
		this.name = name;
		this.icon = icon;
		this.title = title;
		const selected_model = this.models[0] as Model | undefined;
		this.selected_model_name = selected_model?.name;
		this.url = url;
	}
}
