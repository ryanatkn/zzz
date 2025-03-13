import {Filer, type Cleanup_Watch} from '@ryanatkn/gro/filer.js';
import type {Watcher_Change} from '@ryanatkn/gro/watch_dir.js';
import {resolve} from 'node:path';

import {type Message_Client, type Message_Server} from '$lib/message_types.js';
import type {Zzz_Config} from '$lib/config_helpers.js';
import {Zzz_Dir} from '$lib/diskfile_types.js';
import {Safe_Fs} from '$lib/server/safe_fs.js';

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
	/**
	 * Directories that Zzz is allowed to read from and write to
	 */
	zzz_dir: string;
	/**
	 * Configuration for the server and AI providers
	 */
	config: Zzz_Config;
	/**
	 * Send a message to all connected websocket clients
	 */
	send_to_all_clients: (message: Message_Server) => void;
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
 * Server for managing the Zzz application state and handling client messages
 */
export class Zzz_Server {
	/** The root Zzz directory on the server's filesystem */
	readonly zzz_dir: Zzz_Dir;

	readonly config: Zzz_Config;

	readonly #send_to_all_clients: (message: Message_Server) => void;
	readonly #handle_message: Message_Handler;
	readonly #handle_filer_change: Filer_Change_Handler;

	/**
	 * Safe filesystem interface that restricts operations to allowed directories
	 */
	readonly safe_fs: Safe_Fs;

	// Map of directory paths to their respective Filer instances
	readonly filers: Map<string, Filer_Instance> = new Map();

	constructor(options: Zzz_Server_Options) {
		// Parse the allowed filesystem directories
		this.zzz_dir = Zzz_Dir.parse(resolve(options.zzz_dir)); // TODO if the class get more paths to deal with, add a `cwd` option - for now callers can just resolve to absolute themselves

		this.config = options.config;
		this.#send_to_all_clients = options.send_to_all_clients;
		this.#handle_message = options.handle_message;
		this.#handle_filer_change = options.handle_filer_change;

		// Create the safe filesystem interface with the allowed directories
		this.safe_fs = new Safe_Fs([this.zzz_dir]); // TODO pass filter through on options

		// Set up the filer watcher for the zzz_dir
		console.log(`this.zzz_dir`, this.zzz_dir);
		const filer = new Filer({watch_dir_options: {dir: this.zzz_dir}}); // TODO maybe filter out the db directory at this level? think about this when db is added
		const cleanup_promise = filer.watch((change, source_file) => {
			console.log(`change`, change, source_file.id);
			this.#handle_filer_change(change, source_file, this, this.zzz_dir);
		});
		this.filers.set(this.zzz_dir, {filer, cleanup_promise});
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
		return this.#handle_message(message, this);
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
