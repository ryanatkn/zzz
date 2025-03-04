import {z} from 'zod';
import {SvelteMap} from 'svelte/reactivity';

import {Cell, type Cell_Options, cell_array} from '$lib/cell.svelte.js';
import {Message} from '$lib/message.svelte.js';
import {Message_Json, type Message_Client, type Message_Server} from '$lib/message_types.js';
import type {Uuid} from '$lib/uuid.js';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

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
	#send_handler?: (message: Message_Client) => void;

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
		send_handler: (message: Message_Client) => void,
		receive_handler: (callback: (message: Message_Server) => void) => void,
	): void {
		// Store the send handler
		this.#send_handler = send_handler;

		// Set up receiver to handle incoming messages
		// Instead of storing the receive handler, use it directly
		receive_handler(this.receive.bind(this));
	}

	/**
	 * Send a message using the registered handler with proper typing
	 */
	send(message: Message_Client): void {
		if (!this.#send_handler) {
			console.error('No send handler registered');
			return;
		}

		this.#send_handler(message);
	}

	/**
	 * Handle a received message with proper typing
	 */
	receive(message: Message_Server): void {
		// Process incoming message based on type
		switch (message.type) {
			case 'echo':
				this.zzz.receive_echo(message);
				break;
			case 'completion_response':
				this.zzz.receive_completion_response(message);
				break;
			case 'filer_change':
				this.zzz.files.handle_change(message);
				break;
			case 'loaded_session':
				// Handle loaded_session if needed
				// TODO BLOCK
				break;
			default:
				throw new Unreachable_Error(message);
		}
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

	/**
	 * Get a message by ID
	 */
	get_by_id(id: Uuid): Message | undefined {
		return this.by_id.get(id);
	}

	/**
	 * Clear all messages
	 */
	clear(): void {
		this.items.length = 0;
		this.by_id.clear();
		this.by_time.clear();
	}
}
