import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Chat, Chat_Json} from '$lib/chat.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {reorder_list} from '$lib/list_helpers.js';
import {cell_array} from '$lib/cell_helpers.js';

// Fix the schema definition for Chats_Json
export const Chats_Json = z
	.object({
		// First create the array, then apply default, then attach metadata
		items: cell_array(
			z.array(Chat_Json).default(() => []),
			'Chat',
		),
		selected_id: z.string().nullable().default(null),
	})
	.default(() => ({
		items: [],
		selected_id: null,
	}));

export type Chats_Json = z.infer<typeof Chats_Json>;

export interface Chats_Options extends Cell_Options<typeof Chats_Json> {}

export class Chats extends Cell<typeof Chats_Json> {
	items: Array<Chat> = $state([]);
	selected_id: Uuid | null = $state(null);

	selected: Chat | undefined = $derived(this.items.find((c) => c.id === this.selected_id));
	selected_id_error: boolean = $derived(this.selected_id !== null && this.selected === undefined);

	constructor(options: Chats_Options) {
		super(Chats_Json, options);
		// Initialize explicitly after all properties are defined
		this.init();
	}

	add(json?: Chat_Json): Chat {
		const chat = new Chat({zzz: this.zzz, json});
		this.items.unshift(chat);
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
				} else {
					this.selected_id = null;
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
