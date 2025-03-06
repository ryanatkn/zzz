import {z} from 'zod';
import {SvelteMap} from 'svelte/reactivity';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Message} from '$lib/message.svelte.js';
import {
	Message_Json,
	type Message_Client,
	type Message_Server,
	create_message_json,
	type Message_Type,
} from '$lib/message_types.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {cell_array} from '$lib/cell_helpers.js';

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

export class Messages extends Cell<typeof Messages_Json> {
	items: Array<Message> = $state([]);
	history_limit: number = $state(HISTORY_LIMIT_DEFAULT);

	by_id: SvelteMap<Uuid, Message> = new SvelteMap();

	by_type: SvelteMap<Message_Type, Array<Message>> = new SvelteMap();

	// Derived collections for easy access
	pings: Array<Message> = $derived(this.by_type.get('ping') || []);
	pongs: Array<Message> = $derived(this.by_type.get('pong') || []);
	prompts: Array<Message> = $derived(this.by_type.get('send_prompt') || []);
	completions: Array<Message> = $derived(this.by_type.get('completion_response') || []);
	diskfile_updates: Array<Message> = $derived(this.by_type.get('update_diskfile') || []);
	diskfile_deletes: Array<Message> = $derived(this.by_type.get('delete_diskfile') || []);
	filer_changes: Array<Message> = $derived(this.by_type.get('filer_change') || []);

	// Message handlers
	onsend?: (message: Message_Client) => void;
	#onreceive?: (message: Message_Server) => void;

	constructor(options: Messages_Options) {
		super(Messages_Json, options);
		this.init();

		// Set up indexes after initialization
		this.#rebuild_indexes();
	}

	/**
	 * Add a message to a type collection
	 */
	#add_to_type_collection(message: Message): void {
		const type_collection = this.by_type.get(message.type);
		if (type_collection) {
			type_collection.push(message);
		} else {
			const messages = $state([message]);
			this.by_type.set(message.type, messages);
		}
	}

	/**
	 * Remove a message from a type collection
	 */
	#remove_from_type_collection(message: Message): void {
		const type_collection = this.by_type.get(message.type);
		if (type_collection) {
			const updated_collection = type_collection.filter((m) => m.id !== message.id);
			if (!updated_collection.length) {
				this.by_type.delete(message.type);
			} else {
				this.by_type.set(message.type, updated_collection);
			}
		}
	}

	/**
	 * Rebuild the lookup indexes for the messages
	 */
	#rebuild_indexes(): void {
		this.by_id.clear();
		this.by_type.clear();

		for (const message of this.items) {
			this.by_id.set(message.id, message);
			this.#add_to_type_collection(message);
		}
	}

	/**
	 * Override to rebuild indexes after setting JSON
	 */
	override set_json(value?: z.input<typeof Messages_Json>): void {
		super.set_json(value);
		this.#rebuild_indexes();
	}

	/**
	 * Set message handlers with proper typing
	 */
	set_handlers(
		onsend: (message: Message_Client) => void,
		onreceive: (message: Message_Server) => void,
	): void {
		// Store the send handler
		this.onsend = onsend;
		this.#onreceive = onreceive;
	}

	/**
	 * Send a message using the registered handler with proper typing
	 */
	send(message: Message_Client): void {
		if (!this.onsend) {
			console.error('No send handler registered');
			return;
		}

		this.add(create_message_json(message, 'client'));
		this.onsend(message);
	}

	/**
	 * Handle a received message with proper typing
	 */
	receive(message: Message_Server): void {
		if (!this.#onreceive) {
			console.error('No receive handler registered');
			return;
		}

		this.add(create_message_json(message, 'server'));
		this.#onreceive(message);
	}

	/**
	 * Add a message to the collection
	 */
	add(message_json: Message_Json): Message {
		const message = new Message({zzz: this.zzz, json: message_json});
		this.items.push(message);

		// Update indexes
		this.by_id.set(message.id, message);
		this.#add_to_type_collection(message);

		// Trim collection if it exceeds history limit
		this.#trim_to_history_limit();

		return message;
	}

	/**
	 * Trims the collection to the maximum allowed size by removing oldest messages
	 */
	#trim_to_history_limit(): void {
		if (this.items.length <= this.history_limit) return;

		// Calculate how many items to remove
		const excess = this.items.length - this.history_limit;

		// Remove oldest messages (those at the beginning of the array)
		const removed = this.items.splice(0, excess);

		// Update indexes by removing the references to deleted messages
		for (const message of removed) {
			this.by_id.delete(message.id);
			this.#remove_from_type_collection(message);
		}
	}
}
