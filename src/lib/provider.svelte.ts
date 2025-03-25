import {z} from 'zod';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';

import type {Model} from '$lib/model.svelte.js';
import {Provider_Name} from '$lib/provider_types.js';
import {Cell_Json} from '$lib/cell_types.js';

// TODO optional/defaults?
export const Provider_Json = Cell_Json.extend({
	name: Provider_Name,
	icon: z.string(),
	title: z.string(),
	url: z.string(),
});
export type Provider_Json = z.infer<typeof Provider_Json>;

export interface Provider_Options extends Cell_Options<typeof Provider_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Provider extends Cell<typeof Provider_Json> {
	name: Provider_Name = $state()!;
	icon: string = $state()!;
	title: string = $state()!;
	url: string = $state()!;

	models: Array<Model> = $derived(this.zzz.models.items.where('provider_name', this.name));
	// TODO BLOCK this isn't a thing, each message is to an provider+model
	selected_model_name: string | undefined = $state();
	selected_model: Model | undefined = $derived(
		this.selected_model_name
			? this.zzz.models.items.by_optional('name', this.selected_model_name)
			: undefined,
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
