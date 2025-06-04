import {Filer, type Cleanup_Watch, type Source_File} from '@ryanatkn/gro/filer.js';
import type {Watcher_Change} from '@ryanatkn/gro/watch_dir.js';
import {resolve} from 'node:path';
import {Logger} from '@ryanatkn/belt/log.js';
import {DEV} from 'esm-env';
import {ensure_end} from '@ryanatkn/belt/string.js';

import type {Action_Spec} from '$lib/action_spec.js';
import {Action_Inputs, Action_Outputs, action_spec_by_method} from '$lib/action_collections.js';
import type {Zzz_Config} from '$lib/config_helpers.js';
import {Zzz_Dir} from '$lib/diskfile_types.js';
import {Safe_Fs} from '$lib/server/safe_fs.js';
import {Action_Registry} from '$lib/action_registry.js';
import {stringify_zod_error} from '$lib/zod_helpers.js';
import {
	type Jsonrpc_Request,
	type Jsonrpc_Response,
	type Jsonrpc_Error_Message,
	type Jsonrpc_Notification,
	Jsonrpc_Result,
	Jsonrpc_Message,
	Jsonrpc_Message_From_Client_To_Server,
} from '$lib/jsonrpc.js';
import {handle_jsonrpc_request} from '$lib/server/jsonrpc_server_helpers.js';
import {create_jsonrpc_error_from_thrown, create_jsonrpc_response} from '$lib/jsonrpc_helpers.js';
import {ZZZ_CACHE_DIRNAME} from '$lib/constants.js';
import {to_zzz_cache_dir} from '$lib/diskfile_helpers.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';
import type {Server_Action_Handlers} from '$lib/server/server_action_types.js';
import {Server_Action_Event} from '$lib/server/server_action_event.js';
import {Action_Method} from '$lib/action_metatypes.js';

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
	server_action_handlers: Server_Action_Handlers;
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
	readonly zzz_cache_dir: string;

	readonly config: Zzz_Config;

	readonly #broadcast_jsonrpc_message: (message: Jsonrpc_Message) => void;
	readonly #server_action_handlers: Server_Action_Handlers;
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
		this.#server_action_handlers = options.server_action_handlers;
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

	async handle_jsonrpc_message(
		message: unknown,
	): Promise<Jsonrpc_Response | Jsonrpc_Error_Message | null> {
		// TODO BLOCK @api probably pass through `#receive_jsonrpc_request` and others directly
		return handle_jsonrpc_request({
			message,
			onrequest: async (
				request: Jsonrpc_Request,
			): Promise<Jsonrpc_Response | Jsonrpc_Error_Message> => {
				try {
					const result = await this.#receive_jsonrpc_message(request);
					console.log(`result`, result);

					if (!result)
						throw jsonrpc_errors.internal_error(`no result returned for action: ${request.method}`);

					return create_jsonrpc_response(request.id, result);
				} catch (error) {
					this.log?.error(`Error processing JSON-RPC request:`, error);
					return create_jsonrpc_error_from_thrown(request.id, error);
				}
			},
			onnotification: async (notification: Jsonrpc_Notification): Promise<void> => {
				try {
					// Notifications have no response
					await this.#receive_jsonrpc_message(notification);
				} catch (error) {
					this.log?.error(`Error processing JSON-RPC notification:`, error);
					// No response for notifications, so just log the error
				}
			},
			log: this.log,
		});
	}

	// TODO @many hacky, currently just broadcasting when most cases should have a specified audience
	broadcast_jsonrpc_message(message: Jsonrpc_Message): void {
		this.#check_destroyed();
		this.#broadcast_jsonrpc_message(message);
	}

	// TODO BLOCK @api remove "action message" stuff, just use jsonrpc messages directly, maybe `receive_jsonrpc_request`?
	/**
	 * Process an action by name with parameters.
	 * This is the unified entry point for both HTTP and WebSocket actions.
	 */
	async #receive_jsonrpc_message(
		message: Jsonrpc_Message_From_Client_To_Server,
	): Promise<Jsonrpc_Result | null> {
		if (Array.isArray(message)) {
			throw jsonrpc_errors.invalid_request('array support is not yet implemented'); // TODO
		}
		this.log?.debug(
			`receive`,
			'id' in message ? 'request ' + message.id : 'notification',
			message.method,
		);
		this.#check_destroyed();

		// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
		if (!message) {
			throw jsonrpc_errors.invalid_request();
		}

		const parsed_method = Action_Method.safeParse(message.method);
		if (!parsed_method.success) {
			throw jsonrpc_errors.method_not_found(message.method);
		}
		const method = parsed_method.data;

		const spec = action_spec_by_method.get(method);
		if (!spec) {
			throw jsonrpc_errors.method_not_found(method);
		}

		if (spec.kind !== 'request_response') {
			throw jsonrpc_errors.invalid_request(`invalid action kind for method: ${method}`);
		}

		const input_schema = Action_Inputs[method];
		// TODO BLOCK @api @many maybe change the type or add a helper
		if (!input_schema) {
			throw jsonrpc_errors.internal_error(`unknown message schema: ${method}`);
		}

		const parsed_request = input_schema.safeParse(message);
		if (!parsed_request.success) {
			this.log?.error('failed to validate service params', method, parsed_request.error.issues);
			throw jsonrpc_errors.invalid_params(
				`invalid params to ${method}: ${stringify_zod_error(parsed_request.error)}`,
				{issues: parsed_request.error.issues},
			);
		}

		// TODO BLOCK @api refactor to fix type below
		const method_handlers = this.#server_action_handlers[method];
		const phase =
			method_handlers &&
			('receive_request' in method_handlers
				? 'receive_request'
				: 'receive' in method_handlers
					? 'receive'
					: null);
		const handler = method_handlers && phase && method_handlers[phase];

		if (!handler) {
			throw jsonrpc_errors.internal_error(method); // since there's a spec, this should not happen
		}

		const event = new Server_Action_Event(this, phase, parsed_request.data, message);
		await event.handle(handler);

		// Validate the response during development
		// TODO maybe always validate?
		if (DEV) {
			const output_schema = Action_Outputs[method];
			// TODO BLOCK @api @many maybe change the type or add a helper
			if (!output_schema) {
				throw jsonrpc_errors.internal_error(`unknown response schema: ${method}`);
			}
			const parsed_response = output_schema.safeParse({
				...message,
				params: event.result,
			});
			if (!parsed_response.success) {
				this.log?.error(
					'failed to validate server action response params',
					spec.method,
					event.result,
					parsed_response.error.issues,
				);
				throw jsonrpc_errors.internal_error(
					`server action response validation failed for ${spec.method}: ${stringify_zod_error(parsed_response.error)}`,
					{issues: parsed_response.error.issues},
				);
			}
		}

		return event.result;
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
