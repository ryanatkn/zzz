import {Filer, type Cleanup_Watch} from '@ryanatkn/gro/filer.js';
import type {Watcher_Change} from '@ryanatkn/gro/watch_dir.js';
import {resolve} from 'node:path';
import {Logger} from '@ryanatkn/belt/log.js';
import {DEV} from 'esm-env';

import {Action_Client, type Action_Server, type Action_Spec} from '$lib/schemas.js';
import type {Zzz_Config} from '$lib/config_helpers.js';
import {Zzz_Dir} from '$lib/diskfile_types.js';
import {Safe_Fs} from '$lib/server/safe_fs.js';
import {
	validate_service_params,
	validate_service_response as validate_service_return,
	type Service_Return,
} from '$lib/server/service.js';
import {Api_Error} from '$lib/api.js';
import {action_specs} from '$lib/schema_metadata.js';

/**
 * Function type for handling client messages.
 */
export type Action_Handler = (
	// TODO BLOCK this needs to be fixed
	message: Action_Client,
	server: Zzz_Server,
) => Promise<Service_Return>;

/**
 * Function type for handling file system changes.
 */
export type Filer_Change_Handler = (
	change: Watcher_Change,
	source_file: Record<string, any>,
	server: Zzz_Server,
	dir: Zzz_Dir,
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
	 * Configuration for the server and AI providers.
	 */
	config: Zzz_Config;
	/**
	 * Send a message to all connected websocket clients.
	 */
	send_to_all_clients: (message: Action_Server) => void;
	/**
	 * Handler function for processing client messages.
	 */
	handle_message: Action_Handler;
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

	readonly config: Zzz_Config;

	readonly #send_to_all_clients: (message: Action_Server) => void;
	readonly #handle_message: Action_Handler;
	readonly #handle_filer_change: Filer_Change_Handler;

	/**
	 * Safe filesystem interface that restricts operations to allowed directories.
	 */
	readonly safe_fs: Safe_Fs;

	readonly log: Logger | null;

	// TODO probably extract a `Filers` class to manage these
	// Map of directory paths to their respective Filer instances
	readonly filers: Map<string, Filer_Instance> = new Map();

	readonly action_specs: Array<Action_Spec> = action_specs; // TODO BLOCK option and/or registry class

	constructor(options: Zzz_Server_Options) {
		// Parse the allowed filesystem directories
		this.zzz_dir = Zzz_Dir.parse(resolve(options.zzz_dir)); // TODO if the class get more paths to deal with, add a `cwd` option - for now callers can just resolve to absolute themselves

		this.config = options.config;
		this.#send_to_all_clients = options.send_to_all_clients;
		this.#handle_message = options.handle_message;
		this.#handle_filer_change = options.handle_filer_change;

		// Create the safe filesystem interface with the allowed directories
		this.safe_fs = new Safe_Fs([this.zzz_dir]); // TODO pass filter through on options

		this.log = options.log === undefined ? new Logger('[zzz_server]') : options.log;

		// TODO maybe do this in an `init` method
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
	 * Send a message to all connected clients.
	 */
	send(message: Action_Server): void {
		this.#check_destroyed();

		this.#send_to_all_clients(message);
	}

	/**
	 * Prefer `process_action` instead of this unless you intend to bypass validation.
	 * Handle incoming client messages for all transports
	 * by delegating to the configured handler.
	 */
	async receive(message: Action_Client): Promise<Service_Return> {
		this.#check_destroyed();

		// Sanity check
		if (!message) throw new Api_Error(400, 'invalid message'); // eslint-disable-line @typescript-eslint/no-unnecessary-condition

		this.log?.debug(`receive message`, message.id, message.type);

		return this.#handle_message(message, this);
	}

	/**
	 * Process an action by name with parameters.
	 * This is the unified entry point for both HTTP and WebSocket actions.
	 *
	 * @param action_name_or_message - Either the action name as a string or the full Action_Client object
	 * @param params - Parameters if action_name_or_message is a string, ignored if action_name_or_message is an Action_Client
	 */
	async process_action(
		action_name_or_message: string | Action_Client,
		params?: unknown,
	): Promise<Service_Return> {
		this.#check_destroyed();

		let action_name: string;
		let action_params: unknown;

		// TODO BLOCK make this function monomorphic
		// Determine if we're processing by name or full message
		if (typeof action_name_or_message === 'string') {
			action_name = action_name_or_message;
			action_params = params;
		} else {
			action_name = action_name_or_message.type;
			action_params = action_name_or_message; // The full message is the params
		}

		// Find the action spec
		// TODO BLOCK lookup O(1), probably a registry class?
		const spec = this.action_specs.find((s) => s.name === action_name);
		if (!spec) {
			throw new Api_Error(400, `unknown action: ${action_name}`);
		}

		if (spec.type !== 'Service_Action') {
			throw new Api_Error(400, `action is not a service action: ${action_name}`);
		}

		// Validate parameters based on the schema
		const parsed = validate_service_params(spec, action_params, this.log);
		console.log(`parsed`, parsed);

		// Process the action with validated parameters
		const returned = await this.receive(parsed as any); // TODO typesafe, see `validate_service_params`, probably generated code

		// In development, validate the response
		if (DEV) {
			validate_service_return(spec, returned, this.log);
		}

		return returned;
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
