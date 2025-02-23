import type {Zzz} from '$lib/zzz.svelte.js';
import {random_id, type Id} from '$lib/id.js';

// TODO maybe rename to just `Fragment`? extract to `fragment.svelte.ts`?
export interface Prompt_Fragment {
	id: Id;
	name: string;
	content: string;
}

export interface Prompt_Message {
	role: 'user' | 'system';
	content: Array<Prompt_Message_Content>;
}

export type Prompt_Message_Content = string; // TODO ?

export class Prompt {
	readonly id: Id = random_id();
	name: string = $state('new prompt');
	created: string = new Date().toISOString();
	fragments: Array<Prompt_Fragment> = $state([]);
	zzz: Zzz;

	value: string = $derived(
		this.fragments
			.map((f) => f.content)
			.filter((c) => c.trim().length > 0)
			.join('\n\n'),
	);

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	add_fragment(content: string = '', name: string = 'new fragment'): Prompt_Fragment {
		const fragment: Prompt_Fragment = {
			id: random_id(),
			name,
			content,
		};
		this.fragments.push(fragment);
		return fragment;
	}

	update_fragment(id: Id, updates: Partial<Omit<Prompt_Fragment, 'id'>>): void {
		const fragment = this.fragments.find((f) => f.id === id);
		if (fragment) {
			if (updates.name !== undefined) fragment.name = updates.name;
			if (updates.content !== undefined) fragment.content = updates.content;
		}
	}

	remove_fragment(id: Id): boolean {
		const index = this.fragments.findIndex((f) => f.id === id);
		if (index !== -1) {
			this.fragments.splice(index, 1);
			return true;
		}
		return false;
	}
}
