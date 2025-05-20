import {Filer, type Cleanup_Watch} from '@ryanatkn/gro/filer.js';
import type {Watcher_Change} from '@ryanatkn/gro/watch_dir.js';
import {resolve} from 'node:path';
import {Logger} from '@ryanatkn/belt/log.js';
import {DEV} from 'esm-env';

import {Action_Message_Base, type Action_Spec} from '$lib/action_spec.js';
import {
	Action_Message_From_Client,
	action_spec_by_method,
	type Action_Message_From_Server,
} from '$lib/action_collections.js';
import type {Zzz_Config} from '$lib/config_helpers.js';
import {Zzz_Dir} from '$lib/diskfile_types.js';
import {Safe_Fs} from '$lib/server/safe_fs.js';
import {Action_Registry} from '$lib/action_registry.js';
import type {Service_Return} from '$lib/server/service.js';
import {Api_Error} from '$lib/api.js';
import {is_request_response_action} from '$lib/schema_helpers.js';
import {stringify_zod_error} from '$lib/zod_helpers.js';
import {
	lookup_request_action_schema,
	lookup_response_action_schema,
	to_response_type,
} from '$lib/action_helpers.js';
import {
	type JSONRPCRequest,
	type JSONRPCResponse,
	type JSONRPCError,
	type JSONRPCNotification,
	JSONRPC_VERSION,
} from '$lib/jsonrpc.js';
import {handle_jsonrpc_request, create_jsonrpc_error} from '$lib/server/jsonrpc_server_helpers.js';
import {Action_Message_Type} from '$lib/action_metatypes.js';

/**
 * Function type for handling client messages.
 */
export type Action_Handler = (
	message: Action_Message_From_Client,
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
	 * Action specifications that determine what the server can do.
	 */
	action_specs: Array<Action_Spec>;
	// TODO rethink these
	/**
	 * Send a message to all connected websocket clients.
	 */
	send_to_all_clients: (message: Action_Message_From_Server) => void;
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

	readonly #send_to_all_clients: (message: Action_Message_From_Server) => void;
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
		this.zzz_dir = Zzz_Dir.parse(resolve(options.zzz_dir)); // TODO if the class get more paths to deal with, add a `cwd` option - for now callers can just resolve to absolute themselves

		this.config = options.config;
		this.action_registry = new Action_Registry(options.action_specs);
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

	async handle_request(data: unknown): Promise<JSONRPCResponse | JSONRPCError | null> {
		const request = handle_jsonrpc_request({
			data,
			onrequest: this.#handle_jsonrpc_request,
			onnotification: this.#handle_jsonrpc_notification,
			log: this.log,
		});
		// TODO anything here? are the various concerns all handled in callbacks?
		return request;
	}

	/**
	 * Handler for JSON-RPC requests - converts to Zzz message format
	 */
	#handle_jsonrpc_request = async (
		request: JSONRPCRequest,
	): Promise<JSONRPCResponse | JSONRPCError> => {
		try {
			// Parse the request into an Action_Message_Base using schema
			const action_message = Action_Message_Base.parse({
				id: request.id,
				type: to_response_type(Action_Message_Type.parse(request.method)),
				method: request.method,
				params: request.params,
			});

			// Process with the standard receive method
			const service_return = await this.#receive(action_message);

			// Convert the service return to JSON-RPC format
			if (service_return.ok !== false) {
				return {
					jsonrpc: JSONRPC_VERSION,
					id: request.id,
					result: service_return.value,
				};
			} else {
				return create_jsonrpc_error(request.id, {
					status: service_return.status || 500,
					message: service_return.message,
				});
			}
		} catch (error) {
			this.log?.error(`Error processing JSON-RPC request:`, error);
			return create_jsonrpc_error(request.id, error);
		}
	};

	/**
	 * Handler for JSON-RPC notifications - converts to Zzz message format
	 */
	#handle_jsonrpc_notification = async (notification: JSONRPCNotification): Promise<void> => {
		try {
			// Parse the notification into an Action_Message_Base using schema
			const action_message = Action_Message_Base.parse({
				type: to_response_type(Action_Message_Type.parse(notification.method)),
				method: notification.method,
				params: notification.params,
			});

			// Process with the standard receive method
			await this.#receive(action_message);
		} catch (error) {
			this.log?.error(`Error processing JSON-RPC notification:`, error);
			// No response for notifications, so just log the error
		}
	};

	/**
	 * Send a message to all connected clients.
	 */
	send(message: Action_Message_From_Server): void {
		this.#check_destroyed();
		this.#send_to_all_clients(message);
	}

	// TODO consider extracting a service helper, maybe an abstraction for the Service_Request
	/**
	 * Process an action by name with parameters.
	 * This is the unified entry point for both HTTP and WebSocket actions.
	 */
	async #receive(message: Action_Message_Base): Promise<Service_Return> {
		this.#check_destroyed();

		// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
		if (!message) {
			throw new Api_Error(400, 'invalid message');
		}

		const {method} = message;

		const spec = action_spec_by_method.get(method);
		if (!spec) {
			throw new Api_Error(400, `unknown action: ${method}`);
		}

		if (!is_request_response_action(spec)) {
			throw new Api_Error(400, `invalid action: ${method}`);
		}

		const request_schema = lookup_request_action_schema(method);
		if (!request_schema) {
			throw new Api_Error(400, `unknown message schema: ${method}`);
		}

		console.log(`message`, message);
		const parsed_request = request_schema.safeParse(message);
		if (!parsed_request.success) {
			this.log?.error('failed to validate service params', method, parsed_request.error.issues);
			throw new Api_Error(
				400,
				`invalid params to ${method}: ${stringify_zod_error(parsed_request.error)}`,
			);
		}
		console.log(`params`, parsed_request.data);

		// TODO BLOCK hacky, need to parse the whole message
		const updated_message = {...(message as any), params: parsed_request.data};

		// forwad the validated params which may have defaults -- we don't parse the other fields here
		const returned = await this.#perform_action(updated_message);
		if (!returned.ok) {
			return returned;
		}

		// in dev mode, expensively validate the response
		if (DEV) {
			const response_schema = lookup_response_action_schema(method);
			if (!response_schema) {
				throw new Api_Error(400, `unknown message schema: ${method}`);
			}
			const parsed_response = response_schema.safeParse(returned.value);
			if (!parsed_response.success) {
				this.log?.error(
					'failed to validate service response params',
					spec.method,
					returned.value,
					parsed_response.error.issues,
				);
				throw new Api_Error(
					500,
					`service response validation failed for ${spec.method}: ${stringify_zod_error(parsed_response.error)}`,
				);
			}
		}

		return returned;
	}

	async #perform_action(message: Action_Message_From_Client): Promise<Service_Return> {
		console.log(`perform_action message`, message);
		this.#check_destroyed();

		// Do a simple fast sanity check because validation is an upstream concern
		if (!message) throw new Api_Error(400, 'invalid message'); // eslint-disable-line @typescript-eslint/no-unnecessary-condition

		this.log?.debug(`receive message`, message.id, message.method);

		return this.#handle_message(message, this);
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
