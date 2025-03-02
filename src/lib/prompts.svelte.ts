import type {Zzz} from '$lib/zzz.svelte.js';
import {Prompt} from '$lib/prompt.svelte.js';
import type {Uuid} from '$lib/uuid.js';
import type {Bit} from '$lib/bit.svelte.js';
import {reorder_list} from '$lib/list_helpers.js';

export class Prompts {
	readonly zzz: Zzz;

	items: Array<Prompt> = $state([]);
	selected_id: Uuid | null = $state(null);
	selected: Prompt | undefined = $derived(this.items.find((p) => p.id === this.selected_id));

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	add(): Prompt {
		const prompt = new Prompt({zzz: this.zzz});
		this.items.unshift(prompt); // TODO BLOCK @many use push and render with sort+filter
		if (this.selected_id === null) {
			this.selected_id = prompt.id;
		}
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

	select(prompt_id: Uuid | null): void {
		this.selected_id = prompt_id;
	}

	reorder_prompts(from_index: number, to_index: number): void {
		reorder_list(this.items, from_index, to_index);
	}

	add_bit(): void {
		if (!this.selected) return;
		this.selected.add_bit();
	}

	update_bit(bit_id: Uuid, updates: Partial<Omit<Bit, 'id'>>): void {
		if (!this.selected) return;
		this.selected.update_bit(bit_id, updates);
	}

	remove_bit(bit_id: Uuid): void {
		if (!this.selected) return;
		this.selected.remove_bit(bit_id);
	}
}
