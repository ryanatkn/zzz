import {Filer, type Cleanup_Watch, type Source_File} from '@ryanatkn/gro/filer.js';
import type {Watcher_Change} from '@ryanatkn/gro/watch_dir.js';
import {resolve} from 'node:path';
import {Logger} from '@ryanatkn/belt/log.js';
import {ensure_end} from '@ryanatkn/belt/string.js';

import type {Action_Spec} from '$lib/action_spec.js';
import type {Zzz_Config} from '$lib/config_helpers.js';
import {Diskfile_Path, Zzz_Dir} from '$lib/diskfile_types.js';
import {Safe_Fs} from '$lib/server/safe_fs.js';
import {Action_Registry} from '$lib/action_registry.js';
import {
	JSONRPC_INTERNAL_ERROR,
	Jsonrpc_Message,
	Jsonrpc_Message_From_Server_To_Client,
} from '$lib/jsonrpc.js';
import {create_jsonrpc_error_message, to_jsonrpc_message_id} from '$lib/jsonrpc_helpers.js';
import {ZZZ_CACHE_DIRNAME} from '$lib/constants.js';
import {to_zzz_cache_dir} from '$lib/diskfile_helpers.js';
import type {Backend_Action_Handlers} from '$lib/server/backend_action_types.js';
import {Backend_Action_Event} from '$lib/server/backend_action_event.js';
import type {Action_Phase} from '$lib/action_types.js';
import {Action_Inputs, Action_Outputs} from '$lib/action_collections.js';
import type {Action_Method} from '$lib/action_metatypes.js';

/**
 * Function type for handling file system changes.
 */
export type Filer_Change_Handler = (
	change: Watcher_Change,
	source_file: Source_File,
	server: Zzz_Server,
	dir: string,
) => void;

/**
 * Structure to hold a Filer and its cleanup function.
 */
export interface Filer_Instance {
	filer: Filer;
	cleanup_promise: Promise<Cleanup_Watch>;
}

export interface Zzz_Server_Options {
	/**
	 * Directories that Zzz is allowed to read from and write to.
	 */
	zzz_dir: string;
	/**
	 * Directory name for the Zzz cache.
	 *
	 * @relative
	 * @no_trailing_slash
	 */
	zzz_cache_dirname?: string; // TODO @many move this info to path schemas
	/**
	 * Configuration for the server and AI providers.
	 */
	config: Zzz_Config;
	/**
	 * Action specifications that determine what the server can do.
	 */
	action_specs: Array<Action_Spec>;
	// TODO rethink these
	/**
	 * Send a message to all connected websocket clients.
	 */
	broadcast_jsonrpc_message: (message: Jsonrpc_Message) => void;
	/**
	 * Handler function for processing client messages.
	 */
	backend_action_handlers: Backend_Action_Handlers;
	/**
	 * Handler function for file system changes.
	 */
	handle_filer_change: Filer_Change_Handler;
	/**
	 * Optional logger instance.
	 * Disabled when `null`, and `undefined` falls back to a new `Logger` instance.
	 */
	log?: Logger | null | undefined;
}

/**
 * Server for managing the Zzz application state and handling client messages.
 */
export class Zzz_Server {
	/** The root Zzz directory on the server's filesystem. */
	readonly zzz_dir: Zzz_Dir;
	/** The Zzz cache directory name, defaults to `.zzz`. */
	readonly zzz_cache_dirname: string;
	/** The full path to the Zzz cache directory. */
	readonly zzz_cache_dir: Diskfile_Path;

	readonly config: Zzz_Config;

	readonly #broadcast_jsonrpc_message: (message: Jsonrpc_Message) => void;
	readonly #backend_action_handlers: Backend_Action_Handlers;
	readonly #handle_filer_change: Filer_Change_Handler;

	/**
	 * Safe filesystem interface that restricts operations to allowed directories.
	 */
	readonly safe_fs: Safe_Fs;

	readonly log: Logger | null;

	// TODO probably extract a `Filers` class to manage these
	// Map of directory paths to their respective Filer instances
	readonly filers: Map<string, Filer_Instance> = new Map();

	/**
	 * Action registry for centralized action specification access.
	 */
	readonly action_registry;
	/**
	 * Access to all action specifications.
	 */
	get action_specs(): Array<Action_Spec> {
		return this.action_registry.specs;
	}

	constructor(options: Zzz_Server_Options) {
		// Parse the allowed filesystem directories
		this.zzz_dir = Zzz_Dir.parse(ensure_end(resolve(options.zzz_dir), '/')); // TODO if the class get more paths to deal with, add a `cwd` option - for now callers can just resolve to absolute themselves
		this.zzz_cache_dirname = options.zzz_cache_dirname ?? ZZZ_CACHE_DIRNAME;
		this.zzz_cache_dir = to_zzz_cache_dir(this.zzz_dir, this.zzz_cache_dirname); // TODO if the class get more paths to deal with, add a `cwd` option - for now callers can just resolve to absolute themselves

		this.config = options.config;
		this.action_registry = new Action_Registry(options.action_specs);
		this.#broadcast_jsonrpc_message = options.broadcast_jsonrpc_message;
		this.#backend_action_handlers = options.backend_action_handlers;
		this.#handle_filer_change = options.handle_filer_change;

		// Create the safe filesystem interface with the allowed directories
		this.safe_fs = new Safe_Fs([this.zzz_cache_dir]); // TODO pass filter through on options

		this.log = options.log === undefined ? new Logger('[server]') : options.log;

		// TODO maybe do this in an `init` method
		// Set up the filer watcher for the zzz_cache_dir
		const filer = new Filer({watch_dir_options: {dir: this.zzz_cache_dir}}); // TODO maybe filter out the db directory at this level? think about this when db is added
		const cleanup_promise = filer.watch((change, source_file) => {
			this.#handle_filer_change(change, source_file, this, this.zzz_cache_dir);
		});
		this.filers.set(this.zzz_cache_dir, {filer, cleanup_promise});
	}

	// TODO @api better type safety
	lookup_action_handler(
		method: Action_Method,
		phase: Action_Phase,
	): ((event: any) => any) | undefined {
		const method_handlers = (this.#backend_action_handlers as any)[method];
		if (!method_handlers) return undefined;
		return method_handlers[phase];
	}

	lookup_action_input_schema<T_Method extends Action_Method>(
		method: T_Method,
	): (typeof Action_Inputs)[T_Method] | undefined {
		return Action_Inputs[method] as any;
	}

	lookup_action_output_schema<T_Method extends Action_Method>(
		method: T_Method,
	): (typeof Action_Outputs)[T_Method] | undefined {
		return Action_Outputs[method] as any;
	}

	/**
	 * Process a JSON-RPC message and return a response.
	 * Handles both single messages and batch requests.
	 */
	async receive(message: unknown): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		this.#check_destroyed();

		try {
			const event = Backend_Action_Event.from(this, message);
			event.parse();
			await event.handle();
			return event.build_response();
		} catch (error) {
			// Only programmer errors should reach here because
			// other errors are returned as JSON-RPC errors,
			// and we don't leak any of those details to the client.
			this.log?.error('Unexpected error:', error);
			return this.#create_fatal_error_response(message);
		}
	}

	/**
	 * Create error response for fatal/unexpected errors.
	 */
	#create_fatal_error_response(raw_message: unknown): Jsonrpc_Message_From_Server_To_Client | null {
		// TODO BLOCK @api needs to handle batch messages, and so doesnt use `this` so extract to a helper
		const id = to_jsonrpc_message_id(raw_message);
		return id === null
			? null
			: create_jsonrpc_error_message(id, {
					code: JSONRPC_INTERNAL_ERROR,
					message: 'Internal server error',
				});
	}

	// TODO @many hacky, currently just broadcasting when most cases should have a specified audience
	broadcast_jsonrpc_message(message: Jsonrpc_Message): void {
		this.#check_destroyed();
		this.#broadcast_jsonrpc_message(message);
	}

	#destroyed = false;
	get destroyed(): boolean {
		return this.#destroyed;
	}

	// TODO maybe use a decorator for this?
	/** Throws if the server has been destroyed. */
	#check_destroyed(): void {
		if (this.#destroyed) {
			throw new Error('Server has been destroyed');
		}
	}

	/**
	 * Server teardown and cleanup.
	 */
	async destroy(): Promise<void> {
		if (this.#destroyed) {
			this.log?.warn('Server already destroyed');
			return; // no-op, but maybe should throw?
		}
		this.#destroyed = true;

		this.log?.info('Destroying server');

		// Clean up all filer watchers
		const cleanup_promises: Array<Promise<void>> = [];

		for (const {cleanup_promise} of this.filers.values()) {
			cleanup_promises.push(cleanup_promise.then((cleanup) => cleanup()));
		}

		await Promise.all(cleanup_promises);
	}
}
