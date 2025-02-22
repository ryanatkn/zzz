import type {Zzz} from '$lib/zzz.svelte.js';
import {Provider, type Provider_Json} from '$lib/provider.svelte.js';

export class Providers {
	readonly zzz: Zzz;

	items: Array<Provider> = $state([]);

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	add(provider_json: Provider_Json): void {
		this.items.push(new Provider({zzz: this.zzz, json: provider_json}));
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
