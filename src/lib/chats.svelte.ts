import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Chat, Chat_Json} from '$lib/chat.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';

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

export interface Chats_Options extends Cell_Options<typeof Chats_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type
export class Chats extends Cell<typeof Chats_Json> {
	// Initialize items directly at property declaration for availability to other properties
	readonly items: Indexed_Collection<Chat> = new Indexed_Collection();

	selected_id: Uuid | null = $state(null);
	selected: Chat | undefined = $derived(
		this.selected_id ? this.items.by_id.get(this.selected_id) : undefined,
	);
	selected_id_error: boolean = $derived(this.selected_id !== null && this.selected === undefined);

	constructor(options: Chats_Options) {
		super(Chats_Json, options);

		this.decoders = {
			items: (items) => {
				if (Array.isArray(items)) {
					this.items.clear();
					for (const item_json of items) {
						const chat = new Chat({zzz: this.zzz, json: item_json});
						this.items.add(chat);
					}
				}
				return HANDLED;
			},
		};

		// Initialize explicitly after all properties are defined
		this.init();
	}

	add(json?: Chat_Json): Chat {
		const chat = new Chat({zzz: this.zzz, json});
		this.items.add_first(chat);
		if (this.selected_id === null) {
			this.selected_id = chat.id;
		}
		return chat;
	}

	remove(id: Uuid): void {
		const removed = this.items.remove(id);
		if (removed && id === this.selected_id) {
			// Find next chat to select
			const remaining_items = this.items.array;
			const next_chat = remaining_items.length > 0 ? remaining_items[0] : undefined;
			this.selected_id = next_chat ? next_chat.id : null;
		}
	}

	select(chat_id: Uuid | null): void {
		this.selected_id = chat_id;
	}

	reorder_chats(from_index: number, to_index: number): void {
		this.items.reorder(from_index, to_index);
	}
}
