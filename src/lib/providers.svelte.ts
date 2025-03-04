import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Provider, Provider_Json} from '$lib/provider.svelte.js';
import {cell_array} from '$lib/cell_helpers.js';

export const Providers_Json = z
	.object({
		items: cell_array(
			z.array(Provider_Json).default(() => []),
			'Provider',
		),
	})
	.default(() => ({
		items: [],
	}));

export type Providers_Json = z.infer<typeof Providers_Json>;

export interface Providers_Options extends Cell_Options<typeof Providers_Json> {}

export class Providers extends Cell<typeof Providers_Json> {
	items: Array<Provider> = $state([]);

	constructor(options: Providers_Options) {
		super(Providers_Json, options);
		this.init();
	}

	add(provider: Provider): void {
		this.items.push(provider);
	}

	find_by_name(name: string): Provider | undefined {
		return this.items.find((p) => p.name === name);
	}

	remove_by_name(name: string): void {
		const index = this.items.findIndex((p) => p.name === name);
		if (index !== -1) {
			this.items.splice(index, 1);
		}
	}

	clear(): void {
		this.items.length = 0;
	}
}
