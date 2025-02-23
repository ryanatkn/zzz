import type {Zzz} from '$lib/zzz.svelte.js';
import {Prompt, type Prompt_Fragment} from '$lib/prompt.svelte.js';
import type {Id} from '$lib/id.js';

export class Prompts {
	readonly zzz: Zzz;

	items: Array<Prompt> = $state([]);
	selected_id: Id | null = $state(null);
	selected: Prompt | undefined = $derived(this.items.find((p) => p.id === this.selected_id));

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	add(): Prompt {
		const prompt = new Prompt(this.zzz);
		this.items.unshift(prompt);
		this.selected_id = prompt.id;
		return prompt;
	}

	remove(prompt: Prompt): void {
		const index = this.items.indexOf(prompt);
		if (index !== -1) {
			const removed = this.items.splice(index, 1);
			if (removed[0].id === this.selected_id) {
				const next_prompt = this.items[index === 0 ? 0 : index - 1] as Prompt | undefined;
				if (next_prompt) {
					this.select(next_prompt.id);
				}
			}
		}
	}

	select(prompt_id: Id | null): void {
		this.selected_id = prompt_id;
	}

	add_fragment(): void {
		if (!this.selected) return;
		this.selected.add_fragment();
	}

	update_fragment(fragment_id: Id, updates: Partial<Omit<Prompt_Fragment, 'id'>>): void {
		if (!this.selected) return;
		this.selected.update_fragment(fragment_id, updates);
	}

	remove_fragment(fragment_id: Id): void {
		if (!this.selected) return;
		this.selected.remove_fragment(fragment_id);
	}
}
