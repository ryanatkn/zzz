import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Message} from '$lib/message.svelte.js';
import {
	Message_Json,
	type Message_Client,
	type Message_Server,
	create_message_json,
} from '$lib/message_types.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';

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

export type Message_Indexes = 'by_type';

export class Messages extends Cell<typeof Messages_Json> {
	// Configure indexed collection with type-based indexing statically
	readonly items: Indexed_Collection<Message, Message_Indexes> = new Indexed_Collection({
		indexes: [
			{
				key: 'by_type',
				extractor: (message) => message.type,
				multi: true, // One type can map to multiple messages
			},
		],
	});

	history_limit: number = $state(HISTORY_LIMIT_DEFAULT);

	// Derived collections for easy access
	pings: Array<Message> = $derived(this.items.multi_indexes.by_type?.get('ping') || []);
	pongs: Array<Message> = $derived(this.items.multi_indexes.by_type?.get('pong') || []);
	prompts: Array<Message> = $derived(this.items.multi_indexes.by_type?.get('send_prompt') || []);
	completions: Array<Message> = $derived(
		this.items.multi_indexes.by_type?.get('completion_response') || [],
	);
	diskfile_updates: Array<Message> = $derived(
		this.items.multi_indexes.by_type?.get('update_diskfile') || [],
	);
	diskfile_deletes: Array<Message> = $derived(
		this.items.multi_indexes.by_type?.get('delete_diskfile') || [],
	);
	filer_changes: Array<Message> = $derived(
		this.items.multi_indexes.by_type?.get('filer_change') || [],
	);

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
						const message = new Message({zzz: this.zzz, json: item_json});
						this.items.add(message);
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
	 * Trims the collection to the maximum allowed size by removing oldest messages
	 */
	#trim_to_history_limit(): void {
		if (this.items.array.length <= this.history_limit) return;

		// Calculate how many items to remove
		const excess = this.items.array.length - this.history_limit;

		// Remove oldest items one by one to properly update all indexes
		for (let i = 0; i < excess; i++) {
			if (this.items.array.length > 0) {
				const oldest = this.items.array[0];
				this.items.remove(oldest.id);
			}
		}
	}
}
