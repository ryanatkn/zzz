import {z} from 'zod';
import {SvelteMap} from 'svelte/reactivity';

import {Cell, type Cell_Options, cell_array} from '$lib/cell.svelte.js';
import {Message} from '$lib/message.svelte.js';
import {
	Message_Json,
	type Message_Client,
	type Message_Server,
	create_message_json,
} from '$lib/message_types.js';
import type {Uuid} from '$lib/uuid.js';

// Define the schema with cell_array for proper class association
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

export interface Messages_Options extends Cell_Options<typeof Messages_Json> {}

export class Messages extends Cell<typeof Messages_Json> {
	items: Array<Message> = $state([]);

	// Lookup maps for performance
	by_id: SvelteMap<Uuid, Message> = new SvelteMap();
	by_time: SvelteMap<number, Message> = new SvelteMap();

	// Use proper message types instead of any
	#send_message?: (message: Message_Client) => void;
	#onreceive?: (message: Message_Server) => void;

	// Remove the unused #receive_handler property

	constructor(options: Messages_Options) {
		super(Messages_Json, options);
		this.init();

		// Set up indexes after initialization
		this.#rebuild_indexes();
	}

	/**
	 * Rebuild the lookup indexes for the messages
	 */
	#rebuild_indexes(): void {
		this.by_id.clear();
		this.by_time.clear();

		for (const message of this.items) {
			if (message.id) {
				this.by_id.set(message.id, message);
			}
			// Add other indexes as needed
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
		send_message: (message: Message_Client) => void,
		onreceive: (message: Message_Server) => void,
	): void {
		// Store the send handler
		this.#send_message = send_message;
		this.#onreceive = onreceive;
	}

	/**
	 * Send a message using the registered handler with proper typing
	 */
	send(message: Message_Client): void {
		if (!this.#send_message) {
			console.error('No send handler registered');
			return;
		}

		this.add(create_message_json(message, 'client'));
		this.#send_message(message);
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
		if (message.id) {
			this.by_id.set(message.id, message);
		}

		return message;
	}
}
