import type {Zzz} from '$lib/zzz.svelte.js';
import type {Provider} from '$lib/provider.svelte.js';

export class Providers {
	readonly zzz: Zzz;

	items: Array<Provider> = $state([]);

	constructor(zzz: Zzz) {
		this.zzz = zzz;
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
