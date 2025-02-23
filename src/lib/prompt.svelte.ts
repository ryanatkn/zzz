import type {Zzz} from '$lib/zzz.svelte.js';
import {random_id, type Id} from '$lib/id.js';

export interface Prompt_Message {
	role: 'user' | 'system';
	content: Array<Prompt_Message_Content>;
}

export type Prompt_Message_Content = string; // TODO ?

export class Prompt {
	readonly id: Id = random_id();
	name: string = $state('new prompt'); // TODO BLOCK use the same pattern as Chat to get unique names
	created: string = new Date().toISOString();
	fragments: Array<{id: Id; name: string; content: string}> = $state([]);
	zzz: Zzz;

  value: string = $derived(this.fragments
    .map(f => f.content)
    .filter(c => c.trim().length > 0)
    .join('\n\n'))

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	add_fragment(name: string = 'new fragment', content: string = ''): void {
		this.fragments.push({
			id: random_id(),
			name,
			content,
		});
	}

	update_fragment(id: Id, updates: {name?: string; content?: string}): void {
		const fragment = this.fragments.find((f) => f.id === id);
		if (fragment) {
			if (updates.name !== undefined) fragment.name = updates.name;
			if (updates.content !== undefined) fragment.content = updates.content;
		}
	}

	remove_fragment(id: Id): void {
		const index = this.fragments.findIndex((f) => f.id === id);
		if (index !== -1) {
			this.fragments.splice(index, 1);
		}
	}
 
}
