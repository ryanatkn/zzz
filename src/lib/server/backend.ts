import {Filer} from '@ryanatkn/gro/filer.js';
import type {Disknode} from '@ryanatkn/gro/disknode.js';
import type {WatcherChange} from '@ryanatkn/gro/watch_dir.js';
import {resolve} from 'node:path';
import {Logger} from '@ryanatkn/belt/log.js';
import type {BackendProviderOllama} from '$lib/server/backend_provider_ollama.js';
import type {BackendProviderGemini} from '$lib/server/backend_provider_gemini.js';
import type {BackendProviderChatgpt} from '$lib/server/backend_provider_chatgpt.js';
import type {BackendProviderClaude} from '$lib/server/backend_provider_claude.js';

import type {ActionSpecUnion} from '$lib/action_spec.js';
import type {ZzzConfig} from '$lib/config_helpers.js';
import {DiskfileDirectoryPath} from '$lib/diskfile_types.js';
import {ScopedFs} from '$lib/server/scoped_fs.js';
import {ActionRegistry} from '$lib/action_registry.js';
import {ZZZ_CACHE_DIR} from '$lib/constants.js';
import type {BackendActionHandlers} from '$lib/server/backend_action_types.js';
import type {ActionEventPhase, ActionEventEnvironment} from '$lib/action_event_types.js';
import type {ActionMethod} from '$lib/action_metatypes.js';
import {
	create_backend_actions_api,
	type BackendActionsApi,
} from '$lib/server/backend_actions_api.js';
import {ActionPeer} from '$lib/action_peer.js';
import type {JsonrpcMessageFromServerToClient} from '$lib/jsonrpc.js';
import type {ActionExecutor} from '$lib/action_types.js';
import type {BackendProvider} from '$lib/server/backend_provider.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';

// TODO refactor for extensibility
interface BackendProviders {
	ollama: BackendProviderOllama;
	gemini: BackendProviderGemini;
	chatgpt: BackendProviderChatgpt;
	claude: BackendProviderClaude;
}

/**
 * Function type for handling file system changes.
 */
export type FilerChangeHandler = (
	change: WatcherChange,
	disknode: Disknode,
	backend: Backend,
	dir: string,
) => void;

/**
 * Structure to hold a Filer and its cleanup function.
 */
export interface FilerInstance {
	filer: Filer;
	cleanup_promise: Promise<() => void>;
}

export interface BackendOptions {
	/**
	 * Directory path for the Zzz cache.
	 */
	zzz_cache_dir?: string; // TODO @many move this info to path schemas
	/**
	 * Configuration for the backend and AI providers.
	 */
	config: ZzzConfig;
	/**
	 * Action specifications that determine what the backend can do.
	 */
	action_specs: Array<ActionSpecUnion>;
	/**
	 * Handler function for processing client messages.
	 */
	action_handlers: BackendActionHandlers;
	/**
	 * Handler function for file system changes.
	 */
	handle_filer_change: FilerChangeHandler;
	/**
	 * Optional logger instance.
	 * Disabled when `null`, and `undefined` falls back to a new `Logger` instance.
	 */
	log?: Logger | null | undefined;
}

/**
 * Server for managing the Zzz application state and handling client messages.
 */
export class Backend implements ActionEventEnvironment {
	readonly executor: ActionExecutor = 'backend';

	/** The full path to the Zzz cache directory. */
	readonly zzz_cache_dir: DiskfileDirectoryPath;

	readonly config: ZzzConfig;

	// TODO @many make transports an option?
	readonly peer: ActionPeer = new ActionPeer({environment: this});

	/**
	 * API for backend-initiated actions.
	 */
	readonly api: BackendActionsApi = create_backend_actions_api(this);

	/**
	 * Scoped filesystem interface that restricts operations to allowed directories.
	 */
	readonly scoped_fs: ScopedFs;

	readonly log: Logger | null;

	// TODO probably extract a `Filers` class to manage these
	// Map of directory paths to their respective Filer instances
	readonly filers: Map<string, FilerInstance> = new Map();

	readonly action_registry;

	/** Available actions. */
	get action_specs(): Array<ActionSpecUnion> {
		return this.action_registry.specs;
	}

	readonly #action_handlers: BackendActionHandlers;

	// TODO wrapper class?
	/** Available AI providers. */
	readonly providers: Array<BackendProvider> = [];

	readonly #handle_filer_change: FilerChangeHandler;

	constructor(options: BackendOptions) {
		this.zzz_cache_dir = DiskfileDirectoryPath.parse(
			resolve(options.zzz_cache_dir || ZZZ_CACHE_DIR),
		);

		this.config = options.config;

		this.action_registry = new ActionRegistry(options.action_specs);
		this.#action_handlers = options.action_handlers;
		this.#handle_filer_change = options.handle_filer_change;

		this.scoped_fs = new ScopedFs([this.zzz_cache_dir]); // TODO pass filter through on options

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
		method: ActionMethod,
		phase: ActionEventPhase,
	): ((event: any) => any) | undefined {
		const method_handlers = this.#action_handlers[method as keyof BackendActionHandlers];
		if (!method_handlers) return undefined;
		return method_handlers[phase as keyof BackendActionHandlers[keyof BackendActionHandlers]];
	}

	lookup_action_spec(method: ActionMethod): ActionSpecUnion | undefined {
		return this.action_registry.spec_by_method.get(method);
	}

	lookup_provider<T extends keyof BackendProviders>(provider_name: T): BackendProviders[T] {
		const provider = this.providers.find((p) => p.name === provider_name);
		if (!provider) {
			throw jsonrpc_errors.invalid_params(`unsupported provider: ${provider_name}`);
		}
		return provider as BackendProviders[T];
	}

	/**
	 * Process a singular JSON-RPC message and return a response.
	 * Like MCP, Zzz breaks from JSON-RPC by not supporting batching.
	 */
	async receive(message: unknown): Promise<JsonrpcMessageFromServerToClient | null> {
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

	add_provider(provider: BackendProvider): void {
		if (this.providers.some((p) => p.name === provider.name)) {
			throw new Error(`provider with name ${provider.name} already exists`);
		}
		this.providers.push(provider);
		this.log?.info(`added provider: ${provider.name}`);
	}
}
