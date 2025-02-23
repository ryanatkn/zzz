import type {Zzz} from '$lib/zzz.svelte.js';
import {random_id, type Id} from '$lib/id.js';

// TODO maybe rename to just `Fragment`? extract to `fragment.svelte.ts`?
export interface Prompt_Fragment {
	id: Id;
	name: string;
	content: string;
	is_file: boolean;
	file_path: string;
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

	value: string = $derived(join_prompt_fragments(this.fragments));
	length: number = $derived(this.value.length); // TODO use segmenter for more precision? will it be slow for large values tho?
	token_count: number = $derived(Math.round(this.length / 4)); // TODO use a tokenizer

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	add_fragment(
		content: string = '',
		name: string = 'new fragment',
		file_path: string = '',
		is_file: boolean = false,
	): Prompt_Fragment {
		const fragment: Prompt_Fragment = {
			id: random_id(),
			name,
			content,
			file_path,
			is_file,
		};
		this.fragments.push(fragment);
		return fragment;
	}

	update_fragment(id: Id, updates: Partial<Omit<Prompt_Fragment, 'id'>>): void {
		const fragment = this.fragments.find((f) => f.id === id);
		if (fragment) {
			if (updates.name !== undefined) fragment.name = updates.name;
			if (updates.content !== undefined) fragment.content = updates.content;
			if (updates.file_path !== undefined) fragment.file_path = updates.file_path;
			if (updates.is_file !== undefined) fragment.is_file = updates.is_file;
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

	remove_all_fragments(): void {
		this.fragments = [];
	}
}

export const join_prompt_fragments = (fragments: Array<Prompt_Fragment>): string =>
	fragments
		.map((f) => {
			const content = f.content.trim();
			if (!content) return '';
			if (!f.is_file) return content;
			return `<File${f.file_path ? ` path="${f.file_path}"` : ''}>\n${content}\n</File>`;
		})
		.filter((c) => !!c)
		.join('\n\n');
