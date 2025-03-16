import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Chat, Chat_Json} from '$lib/chat.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_multi_index, create_derived_index} from '$lib/indexed_collection_helpers.js';

// Define types for index keys
export type Chat_Single_Indexes = never;
export type Chat_Multi_Indexes = never;

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
	readonly items: Indexed_Collection<Chat> = new Indexed_Collection({
		indexes: [
			create_multi_index({
				key: 'by_has_tapes',
				extractor: (chat: Chat) => (chat.tapes.length > 0 ? 'has_tapes' : 'no_tapes'),
				query_schema: z.enum(['has_tapes', 'no_tapes']),
			}),

			create_derived_index({
				key: 'recent_chats',
				compute: (collection) => {
					// Sort chats by creation date (newest first)
					// This is just an example of a derived index
					return [...collection.all].sort(
						(a, b) => new Date(b.created).getTime() - new Date(a.created).getTime(),
					);
				},
				on_add: (collection, item) => {
					// Insert the new chat in the correct position based on creation date
					const index = collection.findIndex(
						(existing) => new Date(existing.created).getTime() <= new Date(item.created).getTime(),
					);
					if (index === -1) {
						collection.push(item);
					} else {
						collection.splice(index, 0, item);
					}
					return collection;
				},
			}),
		],
	});

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

	add(json?: Chat_Json): Chat {
		const chat = new Chat({zzz: this.zzz, json});
		this.items.add_first(chat);
		if (this.selected_id === null) {
			this.selected_id = chat.id;
		}
		return chat;
	}

	add_many(chats_json: Array<Chat_Json>): Array<Chat> {
		const chats = chats_json.map((json) => new Chat({zzz: this.zzz, json}));

		// Add all chats to the beginning of the collection
		for (let i = chats.length - 1; i >= 0; i--) {
			this.items.add_first(chats[i]);
		}

		// Select the first chat if none is currently selected
		if (this.selected_id === null && chats.length > 0) {
			this.selected_id = chats[0].id;
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
		// Store the current selected ID
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
