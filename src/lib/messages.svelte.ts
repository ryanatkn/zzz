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
import {Indexed_Collection, type Index_Value_Types} from '$lib/indexed_collection.svelte.js';

export const HISTORY_LIMIT_DEFAULT = 512;

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

// Define our index keys and their corresponding value types
export type Message_Indexes = 'by_type';
export interface Message_Index_Values extends Index_Value_Types<Message_Indexes> {
	by_type: Message_Type;
}

export class Messages extends Cell<typeof Messages_Json> {
	// Configure indexed collection with type-safe indexing
	readonly items: Indexed_Collection<Message, Message_Indexes, Message_Index_Values> =
		new Indexed_Collection({
			indexes: [
				{
					key: 'by_type',
					extractor: (message) => message.type,
					multi: true,
				},
			],
		});

	history_limit: number = $state(HISTORY_LIMIT_DEFAULT);

	// Using the new, simpler API with the by() helper
	pings: Array<Message> = $derived(this.by('type', 'ping'));
	pongs: Array<Message> = $derived(this.by('type', 'pong'));
	prompts: Array<Message> = $derived(this.by('type', 'send_prompt'));
	completions: Array<Message> = $derived(this.by('type', 'completion_response'));
	diskfile_updates: Array<Message> = $derived(this.by('type', 'update_diskfile'));
	diskfile_deletes: Array<Message> = $derived(this.by('type', 'delete_diskfile'));
	filer_changes: Array<Message> = $derived(this.by('type', 'filer_change'));

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

	// TODO remove this, maybe move to base class
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

	// Remove the get_related_messages method as it's now redundant with the `related` method

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
