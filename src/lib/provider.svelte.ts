import {z} from 'zod';
import {Serializable, type Serializable_Options} from '$lib/serializable.svelte.js';

import type {Model} from '$lib/model.svelte.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {Provider_Name} from '$lib/provider.schema.js';

// TODO optional/defaults?
export const Provider_Json = z.object({
	name: Provider_Name,
	icon: z.string(),
	title: z.string(),
	url: z.string(),
});
export type Provider_Json = z.infer<typeof Provider_Json>;

export interface Provider_Options extends Serializable_Options<typeof Provider_Json, Zzz> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

// TODO BLOCK `Provider` is the wrong word here, more like Model_Service
export class Provider extends Serializable<typeof Provider_Json, Zzz> {
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
		// Pass schema and options to base constructor
		super(Provider_Json, options);

		// Initialize properties with the json data
		this.init();

		// Handle any provider-specific initialization after properties are set
		if (!this.selected_model_name && this.models.length > 0) {
			this.selected_model_name = this.models[0]?.name;
		}
	}
}
