import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Message} from '$lib/message.svelte.js';
import {
	Message_Json,
	type Message_Client,
	type Message_Server,
	create_message_json,
	Message_Type,
} from '$lib/message_types.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection, Index_Type} from '$lib/indexed_collection.svelte.js';

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
			{
				key: 'by_type',
				type: Index_Type.MULTI,
				extractor: (message: Message) => message.type,
			},
			// Ping ID index for pongs
			{
				key: 'by_ping_id',
				type: Index_Type.MULTI,
				extractor: (message: Message) => {
					if (message.type === 'pong') {
						return message.ping_id;
					}
					return undefined;
				},
			},
			// Derived index for latest pongs - prioritize showing most recent
			{
				key: 'latest_pongs',
				type: Index_Type.DERIVED,
				compute: (collection) => {
					return collection
						.where('by_type', 'pong')
						.sort((a, b) => b.created.localeCompare(a.created))
						.slice(0, PONG_DISPLAY_LIMIT);
				},
				matches: (item) => item.type === 'pong',
				on_add: (items, item) => {
					if (item.type !== 'pong') return;

					// Insert at correct position based on created timestamp
					const index = items.findIndex((existing) => item.created > existing.created);

					if (index === -1) {
						items.push(item);
					} else {
						items.splice(index, 0, item);
					}

					// Keep only the newest items
					items.splice(PONG_DISPLAY_LIMIT);
				},
				on_remove: (items, item) => {
					const index = items.findIndex((i) => i.id === item.id);
					if (index !== -1) {
						items.splice(index, 1);
					}
				},
			},
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
	 * Override to populate the indexed collection after parsing JSON
	 */
	override set_json(value?: z.input<typeof Messages_Json>): void {
		super.set_json(value);

		// Trim to history limit after loading
		this.#trim_to_history_limit(); // TODO should be unnecessary to override `set_json` for this
	}

	/**
	 * Send a message using the registered handler with proper typing
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
	 * Handle a received message with proper typing
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
	 * Add a message to the collection
	 */
	add(message_json: Message_Json): Message {
		const message = new Message({zzz: this.zzz, json: message_json});
		this.items.add(message);

		// Trim collection if it exceeds history limit
		this.#trim_to_history_limit();

		return message;
	}

	/**
	 * Get messages by any property value
	 * A generic helper that fetches messages filtered by any property
	 *
	 * @param property The property name to filter by (must be indexed)
	 * @param value The value to filter for
	 * @param limit Maximum number of messages to return (defaults to history_limit)
	 */
	by<K extends keyof Message>(property: K, value: Message[K], limit?: number): Array<Message> {
		// When filtering by type, we use the special 'by_type' index
		if (property === 'type') {
			return this.items.latest('by_type', value as Message_Type, limit || this.history_limit);
		}

		// For other properties, we'd need to add more indexes or implement filtering
		console.warn(`No index available for property: ${property as string}`);
		return [];
	}

	/**
	 * Get the latest N messages of a specific type
	 *
	 * @param type The message type to filter by
	 * @param limit Maximum number of messages to return (defaults to history_limit)
	 * @returns Array of messages matching the type
	 */
	get_latest_by_type(type: Message_Type, limit: number = this.history_limit): Array<Message> {
		return this.items.latest('by_type', type, limit);
	}

	/**
	 * Find pings related to pongs using the index
	 *
	 * @param pongs The pong messages
	 * @returns Array of related ping messages
	 */
	get_pings_for_pongs(pongs: Array<Message>): Array<Message> {
		return pongs
			.filter((pong) => pong.ping_id !== undefined)
			.map((pong) => this.items.by_id.get(pong.ping_id!))
			.filter((ping): ping is Message => ping !== undefined);
	}

	/**
	 * Trims the collection to the maximum allowed size by removing oldest messages
	 */
	#trim_to_history_limit(): void {
		if (this.items.all.length <= this.history_limit) return;

		// Calculate how many items to remove
		const excess = this.items.all.length - this.history_limit;

		// Remove oldest items one by one to properly update all indexes
		for (let i = 0; i < excess; i++) {
			if (this.items.all.length > 0) {
				const oldest = this.items.all[0];
				this.items.remove(oldest.id);
			}
		}
	}
}
