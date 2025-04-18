import {z} from 'zod';
import {goto} from '$app/navigation';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Chat, Chat_Json, Chat_Schema, type Chat_Json_Input} from '$lib/chat.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_single_index, create_derived_index} from '$lib/indexed_collection_helpers.js';
import {to_reordered_list} from '$lib/list_helpers.js';
import {get_unique_name} from '$lib/helpers.js';
import {to_chats_url} from '$lib/nav_helpers.js';

export const Chats_Json = z
	.object({
		// First create the array, then apply default, then attach metadata
		items: cell_array(
			z.array(Chat_Json).default(() => []),
			'Chat',
		),
		selected_id: z.string().nullable().default(null),
		show_sort_controls: z.boolean().default(false),
	})
	.default(() => ({
		items: [],
		selected_id: null,
		show_sort_controls: false,
	}));
export type Chats_Json = z.infer<typeof Chats_Json>;
export type Chats_Json_Input = z.input<typeof Chats_Json>;

export interface Chats_Options extends Cell_Options<typeof Chats_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Chats extends Cell<typeof Chats_Json> {
	readonly items: Indexed_Collection<Chat> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'by_name',
				extractor: (chat) => chat.name,
				query_schema: z.string(),
				result_schema: Chat_Schema,
			}),

			create_derived_index({
				key: 'manual_order',
				compute: (collection) => Array.from(collection.by_id.values()),
				result_schema: z.array(Chat_Schema),
			}),
		],
	});

	selected_id: Uuid | null = $state(null);
	readonly selected: Chat | undefined = $derived(
		this.selected_id ? this.items.by_id.get(this.selected_id) : undefined,
	);
	readonly selected_id_error: boolean = $derived(
		this.selected_id !== null && this.selected === undefined,
	);

	/** Controls visibility of sort controls in the chats list. */
	show_sort_controls: boolean = $state(false);

	/** Ordered array of chats derived from the `manual_order` index. */
	readonly ordered_items: Array<Chat> = $derived(this.items.derived_index('manual_order'));

	readonly items_by_name = $derived(this.items.single_index('by_name'));

	constructor(options: Chats_Options) {
		super(Chats_Json, options);

		this.decoders = {
			// TODO @many maybe infer or create a helper for this, duplicated many places
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

	add(json?: Chat_Json_Input, select?: boolean): Chat {
		const j = !json?.name ? {...json, name: this.generate_unique_name('new chat')} : json;
		const chat = new Chat({zzz: this.zzz, json: j});
		return this.add_chat(chat, select);
	}

	generate_unique_name(base_name: string = 'new chat'): string {
		return get_unique_name(base_name, this.items_by_name);
	}

	add_chat(chat: Chat, select?: boolean): Chat {
		this.items.add(chat);
		if (select || this.selected_id === null) {
			this.selected_id = chat.id;
		}
		return chat;
	}

	add_many(chats_json: Array<Chat_Json_Input>, select?: boolean | number): Array<Chat> {
		const chats = chats_json.map((json) => new Chat({zzz: this.zzz, json}));
		this.items.add_many(chats);

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
			void this.select_next();
		}
	}

	remove_many(ids: Array<Uuid>): number {
		// Store the current selected id
		const current_selected = this.selected_id;

		// Remove the chats
		const removed_count = this.items.remove_many(ids);

		// If the selected chat was removed, select a new one
		if (current_selected !== null && ids.includes(current_selected)) {
			void this.select_next();
		}

		return removed_count;
	}

	// TODO @many extract a selection helper class?
	select(chat_id: Uuid | null): void {
		this.selected_id = chat_id;
	}

	select_next(): Promise<void> {
		const {by_id} = this.items;
		const next = by_id.values().next();
		return this.navigate_to(next.value?.id ?? null);
	}

	navigate_to(chat_id: Uuid | null): Promise<void> {
		return goto(to_chats_url(chat_id));
	}

	reorder_chats(from_index: number, to_index: number): void {
		this.items.indexes.manual_order = to_reordered_list(this.ordered_items, from_index, to_index);
	}

	/**
	 * Toggles the visibility of sort controls in the chats list.
	 */
	toggle_sort_controls(value = !this.show_sort_controls): void {
		this.show_sort_controls = value;
	}
}

export const Chats_Schema = z.instanceof(Chats);
