import type {Zzz} from '$lib/zzz.svelte.js';
import {Chat} from '$lib/chat.svelte.js';
import type {Id} from '$lib/id.js';

export class Chats {
	readonly zzz: Zzz;

	items: Array<Chat> = $state([]);
	selected_id: Id | null = $state(null);
	selected: Chat | undefined = $derived(this.items.find((c) => c.id === this.selected_id));
	// TODO use this
	selected_id_error: boolean = $derived(this.selected_id !== null && this.selected === undefined);

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	add(): void {
		const chat = new Chat(this.zzz);
		this.items.unshift(chat);
		if (this.selected_id === null) {
			this.selected_id = chat.id;
		}
	}

	remove(chat: Chat): void {
		const index = this.items.indexOf(chat);
		if (index !== -1) {
			const removed = this.items.splice(index, 1);
			if (removed[0].id === this.selected_id) {
				const next_chat = this.items[index === 0 ? 0 : index - 1] as Chat | undefined;
				if (next_chat) {
					this.select(next_chat.id);
				}
			}
		}
	}

	select(chat_id: Id | null): void {
		this.selected_id = chat_id;
	}
}
