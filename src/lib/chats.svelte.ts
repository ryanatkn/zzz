import type {Zzz} from '$lib/zzz.svelte.js';
import {Chat, Chat_Json} from '$lib/chat.svelte.js';
import type {Uuid} from '$lib/uuid.js';
import {reorder_list} from '$lib/list_helpers.js';

export class Chats {
	readonly zzz: Zzz;

	items: Array<Chat> = $state([]);
	selected_id: Uuid | null = $state(null);
	selected: Chat | undefined = $derived(this.items.find((c) => c.id === this.selected_id));
	// TODO use this
	selected_id_error: boolean = $derived(this.selected_id !== null && this.selected === undefined);

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	add(json?: Chat_Json): Chat {
		const chat = new Chat({zzz: this.zzz, json});
		this.items.unshift(chat); // TODO BLOCK @many use push and render with sort+filter
		if (this.selected_id === null) {
			this.selected_id = chat.id;
		}
		return chat;
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

	select(chat_id: Uuid | null): void {
		this.selected_id = chat_id;
	}

	reorder_chats(from_index: number, to_index: number): void {
		reorder_list(this.items, from_index, to_index);
	}
}
