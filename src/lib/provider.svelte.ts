import {z} from 'zod';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';

import type {Model} from '$lib/model.svelte.js';
import {Provider_Name, type Provider_Status} from '$lib/provider_types.js';
import {Cell_Json} from '$lib/cell_types.js';

// TODO optional/defaults?
export const Provider_Json = Cell_Json.extend({
	name: Provider_Name,
	title: z.string(),
	// TODO maybe change this to `docs_url` and add `url` for the homepage? and/or some other homepage url property?
	url: z.string(),
	homepage: z.string(), // TODO name? see `url` too
	company: z.string(),
	api_key_url: z.string().nullable(),
}).meta({cell_class_name: 'Provider'});
export type Provider_Json = z.infer<typeof Provider_Json>;
export type Provider_Json_Input = z.input<typeof Provider_Json>;

export interface Provider_Options extends Cell_Options<typeof Provider_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Provider extends Cell<typeof Provider_Json> {
	name: Provider_Name = $state()!;
	title: string = $state()!;
	url: string = $state()!; // TODO @many should these be optional? or just default to `''`? need init patterns
	homepage: string = $state()!; // TODO @many should these be optional? or just default to `''`? need init patterns
	company: string = $state()!;
	api_key_url: string | null = $state()!;

	readonly models: Array<Model> = $derived(this.app.models.items.where('provider_name', this.name));

	/**
	 * Status for this provider (availability, error messages, etc.).
	 */
	readonly status: Provider_Status | null = $derived(this.app.lookup_provider_status(this.name));

	/**
	 * Whether this provider is available (configured with API keys, etc.).
	 */
	readonly available: boolean = $derived(this.status?.available ?? false);

	constructor(options: Provider_Options) {
		super(Provider_Json, options);
		this.init();
	}
}
