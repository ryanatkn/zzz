import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Message, Message_Schema} from '$lib/message.svelte.js';
import {
	Message_Json,
	type Message_Client,
	type Message_Server,
	create_message_json,
	Message_Type,
} from '$lib/message_types.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_multi_index, create_derived_index} from '$lib/indexed_collection_helpers.js';

export const HISTORY_LIMIT_DEFAULT = 512;
export const PONG_DISPLAY_LIMIT = 6;

export const Messages_Json = z
	.object({
		items: cell_array(
			z.array(Message_Json).default(() => []),
			'Message',
		),
	})
	.default(() => ({
		items: [],
	}));

export type Messages_Json = z.infer<typeof Messages_Json>;

export interface Messages_Options extends Cell_Options<typeof Messages_Json> {
	history_limit?: number;
}

// Define our index keys for type safety
export type Message_Multi_Index_Keys = 'by_type' | 'by_ping_id';

export class Messages extends Cell<typeof Messages_Json> {
	// Configure indexed collection with unified indexing system
	readonly items: Indexed_Collection<Message> = new Indexed_Collection({
		indexes: [
			// Type-based multi-index
			create_multi_index({
				key: 'by_type',
				extractor: (message) => message.type,
				query_schema: z.enum([
					'ping',
					'pong',
					'send_prompt',
					'completion_response',
					'update_diskfile',
					'delete_diskfile',
					'filer_change',
				]),
				result_schema: Message_Schema,
			}),

			// Ping id index for pongs
			create_multi_index({
				key: 'by_ping_id',
				extractor: (message) => {
					if (message.type === 'pong' && message.ping_id) {
						return message.ping_id;
					}
					return undefined;
				},
				query_schema: z.string(),
				matches: (message) => message.type === 'pong' && !!message.ping_id,
				result_schema: Message_Schema,
			}),

			// Derived index for latest pongs - prioritize showing most recent
			create_derived_index({
				key: 'latest_pongs',
				compute: (collection) => {
					return collection
						.where('by_type', 'pong')
						.sort((a, b) => b.created.localeCompare(a.created))
						.slice(0, PONG_DISPLAY_LIMIT);
				},
				matches: (item) => item.type === 'pong',
				result_schema: Message_Schema,
				onadd: (items, item) => {
					if (item.type !== 'pong') return items;

					// Insert at correct position based on created timestamp
					const index = items.findIndex((existing) => item.created > existing.created);

					if (index === -1) {
						items.push(item);
					} else {
						items.splice(index, 0, item);
					}

					// Keep only the newest items
					if (items.length > PONG_DISPLAY_LIMIT) {
						return items.slice(0, PONG_DISPLAY_LIMIT);
					}

					return items;
				},
				onremove: (items, item) => {
					const index = items.findIndex((i) => i.id === item.id);
					if (index !== -1) {
						items.splice(index, 1);
					}
					return items;
				},
			}),
		],
	});

	history_limit: number = $state(HISTORY_LIMIT_DEFAULT);

	// Derived collections using the indexed structure
	pings: Array<Message> = $derived(this.items.where('by_type', 'ping'));
	pongs: Array<Message> = $derived(this.items.where('by_type', 'pong'));
	prompts: Array<Message> = $derived(this.items.where('by_type', 'send_prompt'));
	completions: Array<Message> = $derived(this.items.where('by_type', 'completion_response'));
	diskfile_updates: Array<Message> = $derived(this.items.where('by_type', 'update_diskfile'));
	diskfile_deletes: Array<Message> = $derived(this.items.where('by_type', 'delete_diskfile'));
	filer_changes: Array<Message> = $derived(this.items.where('by_type', 'filer_change'));

	// Message handlers
	onsend?: (message: Message_Client) => void;
	onreceive?: (message: Message_Server) => void;

	constructor(options: Messages_Options) {
		super(Messages_Json, options);

		// Set history limit if provided
		if (options.history_limit !== undefined) {
			this.history_limit = options.history_limit;
		}

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

		this.init();
	}

	/**
	 * Override to populate the indexed collection after parsing JSON.
	 */
	override set_json(value?: z.input<typeof Messages_Json>): void {
		super.set_json(value);

		// Trim to history limit after loading
		this.#trim_to_history_limit(); // TODO should be unnecessary to override `set_json` for this
	}

	/**
	 * Send a message using the registered handler with proper typing.
	 */
	send(message: Message_Client): void {
		if (!this.onsend) {
			console.error('No send handler registered', message);
			return;
		}

		this.add(create_message_json(message, 'client'));
		this.onsend(message);
	}

	/**
	 * Handle a received message with proper typing.
	 */
	receive(message: Message_Server): void {
		if (!this.onreceive) {
			console.error('No receive handler registered');
			return;
		}

		this.add(create_message_json(message, 'server'));
		this.onreceive(message);
	}

	/**
	 * Add a message to the collection.
	 */
	add(message_json: Message_Json): Message {
		const message = new Message({zzz: this.zzz, json: message_json});
		this.items.add(message);

		// Trim collection if it exceeds history limit
		this.#trim_to_history_limit();

		return message;
	}

	/**
	 * Get the latest N messages of a specific type.
	 *
	 * @param type The message type to filter by
	 * @param limit Maximum number of messages to return (defaults to history_limit)
	 * @returns Array of messages matching the type
	 */
	get_latest_by_type(type: Message_Type, limit: number = this.history_limit): Array<Message> {
		return this.items.latest('by_type', type, limit);
	}

	/**
	 * Trims the collection to the maximum allowed size by removing oldest messages.
	 */
	#trim_to_history_limit(): void {
		// Calculate how many items to remove and use the optimized method
		const excess = this.items.all.length - this.history_limit;
		if (excess <= 0) return;
		this.items.remove_first_many(excess);
	}
}
