import {z} from 'zod';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';

import type {Model} from '$lib/model.svelte.js';
import {Provider_Name} from '$lib/provider_types.js';
import {Cell_Json} from '$lib/cell_types.js';

// TODO optional/defaults?
export const Provider_Json = Cell_Json.extend({
	name: Provider_Name,
	title: z.string(),
	url: z.string(),
});
export type Provider_Json = z.infer<typeof Provider_Json>;
export type Provider_Json_Input = z.input<typeof Provider_Json>;

export interface Provider_Options extends Cell_Options<typeof Provider_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Provider extends Cell<typeof Provider_Json> {
	name: Provider_Name = $state()!;
	title: string = $state()!;
	url: string = $state()!;

	readonly models: Array<Model> = $derived(this.app.models.items.where('provider_name', this.name));

	constructor(options: Provider_Options) {
		super(Provider_Json, options);
		this.init();
	}
}
