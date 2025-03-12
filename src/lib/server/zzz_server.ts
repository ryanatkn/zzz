import {Filer, type Cleanup_Watch} from '@ryanatkn/gro/filer.js';
import type {Watcher_Change} from '@ryanatkn/gro/watch_dir.js';

import {type Message_Client, type Message_Server} from '$lib/message_types.js';
import type {Zzz_Config} from '$lib/config_helpers.js';

const ZZZ_DIR_DEFAULT = './.zzz'; // TODO BLOCK @many root_dirs

/**
 * Function type for handling client messages
 */
export type Message_Handler = (
	message: Message_Client,
	server: Zzz_Server,
) => Promise<Message_Server | null>;

/**
 * Function type for handling file system changes
 */
export type Filer_Change_Handler = (
	change: Watcher_Change,
	source_file: Record<string, any>,
	server: Zzz_Server,
) => void;

export interface Zzz_Server_Options {
	send_to_all_clients: (message: Message_Server) => void;
	/**
	 * @default ZZZ_DIR_DEFAULT
	 */
	zzz_dir?: string; // TODO rename to `filesystem_dirs` or something? `zzz_dirs`?
	filer?: Filer;
	/**
	 * Configuration for the server and AI providers
	 */
	config: Zzz_Config;
	/**
	 * Handler function for processing client messages
	 */
	handle_message: Message_Handler;
	/**
	 * Handler function for file system changes
	 */
	handle_filer_change: Filer_Change_Handler;
}

/**
 * Server for managing the ZZZ application state and handling client messages
 */
export class Zzz_Server {
	#send_to_all_clients: (message: Message_Server) => void;

	zzz_dir: string;
	filer: Filer;
	config: Zzz_Config;

	handle_message: Message_Handler;
	handle_filer_change: Filer_Change_Handler;

	#cleanup_filer: Promise<Cleanup_Watch>;

	constructor(options: Zzz_Server_Options) {
		console.log('create Zzz_Server');
		this.#send_to_all_clients = options.send_to_all_clients;
		this.zzz_dir = options.zzz_dir ?? ZZZ_DIR_DEFAULT;
		this.filer = options.filer ?? new Filer({watch_dir_options: {dir: this.zzz_dir}});

		// Store the message and filer change handlers
		this.handle_message = options.handle_message;
		this.handle_filer_change = options.handle_filer_change;

		// Set up the filer watcher with the handler
		this.#cleanup_filer = this.filer.watch((change, source_file) => {
			this.handle_filer_change(change, source_file, this);
		});

		// Store the config directly
		this.config = options.config;
	}

	/**
	 * Send a message to all connected clients
	 */
	send(message: Message_Server): void {
		this.#send_to_all_clients(message);
	}

	/**
	 * Handle incoming client messages by delegating to the configured handler
	 */
	async receive(message: Message_Client): Promise<Message_Server | null> {
		console.log(`[zzz_server.receive] message`, message.id, message.type);
		return this.handle_message(message, this);
	}

	/**
	 * Clean up resources when server is shutting down
	 */
	async destroy(): Promise<void> {
		const cleanup_filer = await this.#cleanup_filer;
		await cleanup_filer();
	}
}
