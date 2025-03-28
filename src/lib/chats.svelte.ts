import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Chat, Chat_Json} from '$lib/chat.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';

export type Chat_Single_Indexes = never;
export type Chat_Multi_Indexes = never;

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
						this.add(item_json);
					}
				}
				return HANDLED;
			},
		};

		// Initialize explicitly after all properties are defined
		this.init();
	}

	add(json?: Chat_Json, first = true, select?: boolean): Chat {
		const chat = new Chat({zzz: this.zzz, json});
		return this.add_chat(chat, first, select);
	}

	add_chat(chat: Chat, first = true, select?: boolean): Chat {
		if (first) {
			this.items.add_first(chat);
		} else {
			this.items.add(chat);
		}
		if (select || this.selected_id === null) {
			this.selected_id = chat.id;
		}
		return chat;
	}

	add_many(chats_json: Array<Chat_Json>, first = true, select?: boolean | number): Array<Chat> {
		const chats = chats_json.map((json) => new Chat({zzz: this.zzz, json}));

		// Add all chats to the beginning of the collection
		for (let i = chats.length - 1; i >= 0; i--) {
			if (first) {
				this.items.add_first(chats[i]);
			} else {
				this.items.add(chats[i]);
			}
		}

		// Select the first or the specified chat if none is currently selected
		if (
			select === true ||
			typeof select === 'number' ||
			(this.selected_id === null && chats.length > 0)
		) {
			this.selected_id = chats[typeof select === 'number' ? select : 0].id;
		}

		return chats;
	}

	remove(id: Uuid): void {
		const removed = this.items.remove(id);
		if (removed && id === this.selected_id) {
			// Find next chat to select
			const remaining_items = this.items.all;
			const next_chat = remaining_items.length > 0 ? remaining_items[0] : undefined;
			this.selected_id = next_chat ? next_chat.id : null;
		}
	}

	remove_many(ids: Array<Uuid>): number {
		// Store the current selected id
		const current_selected = this.selected_id;

		// Remove the chats
		const removed_count = this.items.remove_many(ids);

		// If the selected chat was removed, select a new one
		if (current_selected !== null && ids.includes(current_selected)) {
			const remaining_items = this.items.all;
			const next_chat = remaining_items.length > 0 ? remaining_items[0] : undefined;
			this.selected_id = next_chat ? next_chat.id : null;
		}

		return removed_count;
	}

	select(chat_id: Uuid | null): void {
		this.selected_id = chat_id;
	}

	reorder_chats(from_index: number, to_index: number): void {
		this.items.reorder(from_index, to_index);
	}
}
