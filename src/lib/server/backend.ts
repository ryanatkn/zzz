import {Filer} from '@ryanatkn/gro/filer.js';
import type {Disknode} from '@ryanatkn/gro/disknode.js';
import type {Watcher_Change} from '@ryanatkn/gro/watch_dir.js';
import {resolve} from 'node:path';
import {Logger} from '@ryanatkn/belt/log.js';
import type {Backend_Provider_Ollama} from '$lib/server/backend_provider_ollama.js';
import type {Backend_Provider_Gemini} from '$lib/server/backend_provider_gemini.js';
import type {Backend_Provider_Chatgpt} from '$lib/server/backend_provider_chatgpt.js';
import type {Backend_Provider_Claude} from '$lib/server/backend_provider_claude.js';

import type {Action_Spec_Union} from '$lib/action_spec.js';
import type {Zzz_Config} from '$lib/config_helpers.js';
import {Diskfile_Directory_Path} from '$lib/diskfile_types.js';
import {Scoped_Fs} from '$lib/server/scoped_fs.js';
import {Action_Registry} from '$lib/action_registry.js';
import {ZZZ_CACHE_DIR} from '$lib/constants.js';
import type {Backend_Action_Handlers} from '$lib/server/backend_action_types.js';
import type {Action_Event_Phase, Action_Event_Environment} from '$lib/action_event_types.js';
import type {Action_Method} from '$lib/action_metatypes.js';
import {
	create_backend_actions_api,
	type Backend_Actions_Api,
} from '$lib/server/backend_actions_api.js';
import {Action_Peer} from '$lib/action_peer.js';
import type {Jsonrpc_Message_From_Server_To_Client} from '$lib/jsonrpc.js';
import type {Action_Executor} from '$lib/action_types.js';
import type {Backend_Provider} from '$lib/server/backend_provider.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';

// TODO refactor for extensibility
interface Backend_Providers {
	ollama: Backend_Provider_Ollama;
	gemini: Backend_Provider_Gemini;
	chatgpt: Backend_Provider_Chatgpt;
	claude: Backend_Provider_Claude;
}

/**
 * Function type for handling file system changes.
 */
export type Filer_Change_Handler = (
	change: Watcher_Change,
	disknode: Disknode,
	backend: Backend,
	dir: string,
) => void;

/**
 * Structure to hold a Filer and its cleanup function.
 */
export interface Filer_Instance {
	filer: Filer;
	cleanup_promise: Promise<() => void>;
}

export interface Backend_Options {
	/**
	 * Directory path for the Zzz cache.
	 */
	zzz_cache_dir?: string; // TODO @many move this info to path schemas
	/**
	 * Configuration for the backend and AI providers.
	 */
	config: Zzz_Config;
	/**
	 * Action specifications that determine what the backend can do.
	 */
	action_specs: Array<Action_Spec_Union>;
	/**
	 * Handler function for processing client messages.
	 */
	action_handlers: Backend_Action_Handlers;
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
export class Backend implements Action_Event_Environment {
	readonly executor: Action_Executor = 'backend';

	/** The full path to the Zzz cache directory. */
	readonly zzz_cache_dir: Diskfile_Directory_Path;

	readonly config: Zzz_Config;

	// TODO @many make transports an option?
	readonly peer: Action_Peer = new Action_Peer({environment: this});

	/**
	 * API for backend-initiated actions.
	 */
	readonly api: Backend_Actions_Api = create_backend_actions_api(this);

	/**
	 * Scoped filesystem interface that restricts operations to allowed directories.
	 */
	readonly scoped_fs: Scoped_Fs;

	readonly log: Logger | null;

	// TODO probably extract a `Filers` class to manage these
	// Map of directory paths to their respective Filer instances
	readonly filers: Map<string, Filer_Instance> = new Map();

	readonly action_registry;

	/** Available actions. */
	get action_specs(): Array<Action_Spec_Union> {
		return this.action_registry.specs;
	}

	readonly #action_handlers: Backend_Action_Handlers;

	// TODO wrapper class?
	/** Available AI providers. */
	readonly providers: Array<Backend_Provider> = [];

	readonly #handle_filer_change: Filer_Change_Handler;

	constructor(options: Backend_Options) {
		this.zzz_cache_dir = Diskfile_Directory_Path.parse(
			resolve(options.zzz_cache_dir || ZZZ_CACHE_DIR),
		);

		this.config = options.config;

		this.action_registry = new Action_Registry(options.action_specs);
		this.#action_handlers = options.action_handlers;
		this.#handle_filer_change = options.handle_filer_change;

		this.scoped_fs = new Scoped_Fs([this.zzz_cache_dir]); // TODO pass filter through on options

		this.log = options.log === undefined ? new Logger('[backend]') : options.log;

		// TODO maybe do this in an `init` method
		// Set up the filer watcher for the zzz_cache_dir
		const filer = new Filer({watch_dir_options: {dir: this.zzz_cache_dir}}); // TODO maybe filter out the db directory at this level? think about this when db is added
		const cleanup_promise = filer.watch((change, disknode) => {
			this.#handle_filer_change(change, disknode, this, this.zzz_cache_dir);
		});
		this.filers.set(this.zzz_cache_dir, {filer, cleanup_promise});
	}

	// TODO @api better type safety
	lookup_action_handler(
		method: Action_Method,
		phase: Action_Event_Phase,
	): ((event: any) => any) | undefined {
		const method_handlers = this.#action_handlers[method as keyof Backend_Action_Handlers];
		if (!method_handlers) return undefined;
		return method_handlers[phase as keyof Backend_Action_Handlers[keyof Backend_Action_Handlers]];
	}

	lookup_action_spec(method: Action_Method): Action_Spec_Union | undefined {
		return this.action_registry.spec_by_method.get(method);
	}

	lookup_provider<T extends keyof Backend_Providers>(provider_name: T): Backend_Providers[T] {
		const provider = this.providers.find((p) => p.name === provider_name);
		if (!provider) {
			throw jsonrpc_errors.invalid_params(`unsupported provider: ${provider_name}`);
		}
		return provider as Backend_Providers[T];
	}

	/**
	 * Process a singular JSON-RPC message and return a response.
	 * Like MCP, Zzz breaks from JSON-RPC by not supporting batching.
	 */
	async receive(message: unknown): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		this.#check_destroyed();
		return this.peer.receive(message);
	}

	#destroyed = false;
	get destroyed(): boolean {
		return this.#destroyed;
	}

	// TODO maybe use a decorator for this?
	/** Throws if the backend has been destroyed. */
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
			return;
		}
		this.#destroyed = true;

		this.log?.info('Destroying backend');

		// Clean up all filer watchers
		const cleanup_promises: Array<Promise<void>> = [];

		for (const {cleanup_promise} of this.filers.values()) {
			cleanup_promises.push(cleanup_promise.then((cleanup) => cleanup()));
		}

		await Promise.all(cleanup_promises);
	}

	add_provider(provider: Backend_Provider): void {
		if (this.providers.some((p) => p.name === provider.name)) {
			throw new Error(`provider with name ${provider.name} already exists`);
		}
		this.providers.push(provider);
		this.log?.info(`added provider: ${provider.name}`);
	}
}
