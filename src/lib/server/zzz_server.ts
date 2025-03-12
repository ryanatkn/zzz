import {Filer, type Cleanup_Watch} from '@ryanatkn/gro/filer.js';
import type {Watcher_Change} from '@ryanatkn/gro/watch_dir.js';

import {type Message_Client, type Message_Server} from '$lib/message_types.js';
import type {Zzz_Config} from '$lib/config_helpers.js';
import type {Zzz_Dir} from '$lib/diskfile_types.js';
import {parse_zzz_dirs} from '$lib/server/server_helpers.js';

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
	dir: Zzz_Dir,
) => void;

/**
 * Structure to hold a Filer and its cleanup function
 */
export interface Filer_Instance {
	filer: Filer;
	cleanup_promise: Promise<Cleanup_Watch>;
}

export interface Zzz_Server_Options {
	send_to_all_clients: (message: Message_Server) => void;
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
	/**
	 * Directories that Zzz is allowed to read from and write to
	 */
	zzz_dirs?: string | Array<string>;
}

/**
 * Server for managing the Zzz application state and handling client messages
 */
export class Zzz_Server {
	#send_to_all_clients: (message: Message_Server) => void;

	zzz_dirs: ReadonlyArray<Zzz_Dir>;

	// Map of directory paths to their respective Filer instances
	filers: Map<string, Filer_Instance> = new Map();

	config: Zzz_Config;

	handle_message: Message_Handler;
	handle_filer_change: Filer_Change_Handler;

	constructor(options: Zzz_Server_Options) {
		console.log('create Zzz_Server');
		this.#send_to_all_clients = options.send_to_all_clients;
		this.config = options.config;

		// Store the message and filer change handlers
		this.handle_message = options.handle_message;
		this.handle_filer_change = options.handle_filer_change;

		this.zzz_dirs = parse_zzz_dirs(options.zzz_dirs);

		// TODO BLOCK on the frontend, show each directory and whether or not it even exists, and allow creating it if not
		// Set up a filer for each directory
		for (const dir of this.zzz_dirs) {
			const filer = new Filer({watch_dir_options: {dir}});

			// Set up the filer watcher with the handler
			const cleanup_promise = filer.watch((change, source_file) => {
				this.handle_filer_change(change, source_file, this, dir);
			});

			this.filers.set(dir, {filer, cleanup_promise}); // TODO BLOCK test that this errors on duplicate dirs
		}
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
		// Clean up all filer watchers
		const cleanup_promises: Array<Promise<void>> = [];

		for (const {cleanup_promise} of this.filers.values()) {
			cleanup_promises.push(cleanup_promise.then((cleanup) => cleanup()));
		}

		await Promise.all(cleanup_promises);
	}
}
