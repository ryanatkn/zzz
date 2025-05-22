import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {z} from 'zod';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';
import type {Assignable, Class_Constructor, Omit_Strict} from '@ryanatkn/belt/types.js';

import {Provider, type Provider_Json} from '$lib/provider.svelte.js';
import type {Provider_Name} from '$lib/provider_types.js';
import {create_uuid, get_datetime_now} from '$lib/zod_helpers.js';
import {Models} from '$lib/models.svelte.js';
import {Chats} from '$lib/chats.svelte.js';
import {Tapes} from '$lib/tapes.svelte.js';
import {Providers} from '$lib/providers.svelte.js';
import {Diskfiles} from '$lib/diskfiles.svelte.js';
import {Actions} from '$lib/actions.svelte.js';
import type {Model_Json} from '$lib/model.svelte.js';
import {Cell_Registry} from '$lib/cell_registry.svelte.js';
import {Prompts} from '$lib/prompts.svelte.js';
import {Bits} from '$lib/bits.svelte.js';
import {Time} from '$lib/time.svelte.js';
import type {Zzz_Config} from '$lib/config_helpers.js';
import {BOTS_DEFAULT} from '$lib/config_defaults.js';
import {Zzz_Dir, type Diskfile_Path} from '$lib/diskfile_types.js';
import {ZZZ_CACHE_DIRNAME} from '$lib/constants.js';
import {Url_Params} from '$lib/url_params.svelte.js';
import {cell_classes} from '$lib/cell_classes.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Ui, Ui_Json} from '$lib/ui.svelte.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Socket} from '$lib/socket.svelte.js';
import {Capabilities} from '$lib/capabilities.svelte.js';
import {Diskfile_History} from '$lib/diskfile_history.svelte.js';
import {HANDLED} from '$lib/cell_helpers.js';
import {Action_Registry} from '$lib/action_registry.js';
import {Api_Client, type Api_Client_Options} from '$lib/api_client.js';
import type {Completion_Message} from '$lib/completion_types.js';
import type {Action_Message_Type, Actions_Api, Mutations} from '$lib/action_metatypes.js';
import type {Action_Spec} from '$lib/action_spec.js';
import {action_specs} from '$lib/action_collections.js';
import {create_actions_api} from '$lib/actions_api.js';
import type {Mutation} from '$lib/mutation.js';

export const zzz_context = create_context<Zzz>();

export const Zzz_Json = Cell_Json.extend({
	ui: Ui_Json.default(() => Ui_Json.parse({})),
	// TODO other state?
});
export type Zzz_Json = z.infer<typeof Zzz_Json>;
export type Zzz_Json_Input = z.input<typeof Zzz_Json>;

// Special options type for Zzz to handle circular reference
export interface Zzz_Options extends Omit_Strict<Cell_Options<typeof Zzz_Json>, 'zzz'> {
	/** Do not use - optional to avoid circular reference problem. */
	zzz?: Zzz;
	models?: Array<Model_Json>;
	bots?: Zzz_Config['bots'];
	providers?: Array<Provider_Json>;
	cell_classes?: Record<string, Class_Constructor<Cell>>;
	action_specs?: Array<Action_Spec>;
	mutations?: Mutations;

	/** URL for server communication */
	http_rpc_url?: string | null;

	/** Websocket URL as an optional transport. */
	socket_url?: string | null;

	/** API client options */
	api_client_options?: Api_Client_Options;
}

/**
 * The main client, typically used by creating your own `App extends Zzz`.
 * Gettable with `zzz_context.get()` inside a `<Zzz_Root>`.
 */
export class Zzz extends Cell<typeof Zzz_Json> {
	/**
	 * App-wide cell registry, maps class names to constructor and tracks registered instances.
	 */
	readonly cell_registry: Cell_Registry;

	readonly action_registry: Action_Registry;
	readonly mutations: Mutations & Partial<Record<Action_Message_Type, Mutation<typeof this>>>;
	readonly api: Actions_Api;
	readonly api_client: Api_Client;

	// Cells - these are managed objects/collections that contain the app state
	readonly time: Time;
	readonly ui: Ui;
	readonly models: Models;
	readonly chats: Chats;
	readonly tapes: Tapes;
	readonly providers: Providers;
	readonly prompts: Prompts;
	readonly bits: Bits;
	readonly diskfiles: Diskfiles;
	readonly actions: Actions;
	readonly socket: Socket;
	readonly url_params: Url_Params;
	readonly capabilities: Capabilities;

	readonly bots: Zzz_Config['bots'];

	// TODO maybe instead of this pattern with getters/setters, using an encoder?
	#zzz_dir: Zzz_Dir | null | undefined = $state(null);

	/**
	 * The `zzz_dir` is the path to Zzz's primary directory on the server's filesystem.
	 * The server's `safe_fs` instance restricts operations to this directory.
	 * The value is `undefined` when uninitialized,
	 * `null` when loading, and `''` when disabled or no server.
	 */
	get zzz_dir(): Zzz_Dir | null | undefined {
		return this.#zzz_dir;
	}
	set zzz_dir(value: string | null | undefined) {
		const parsed = value == null ? value : Zzz_Dir.safeParse(value);
		this.#zzz_dir = parsed == null ? parsed : parsed.data;
	}

	zzz_cache_dirname: string = ZZZ_CACHE_DIRNAME; // TODO make this configurable

	zzz_cache_dir: string | null | undefined = $derived(
		this.zzz_dir && this.zzz_dir + this.zzz_cache_dirname,
	);

	// Derived set of all tags from models
	tags: Set<string> = $derived.by(() => {
		const tag_set: Set<string> = new Set();
		for (const model of this.models.items.by_id.values()) {
			for (const tag of model.tags) {
				tag_set.add(tag);
			}
		}
		return tag_set;
	});

	// Store Diskfile_History objects by file path
	readonly diskfile_histories: SvelteMap<Diskfile_Path, Diskfile_History> = new SvelteMap();

	/** See into Zzz's future. */
	futuremode = $state(false);

	constructor(options: Zzz_Options = EMPTY_OBJECT) {
		// Pass this instance as its own zzz reference - casting hacks around the circular reference
		super(Zzz_Json, options as Zzz_Options & {zzz: Zzz});

		// Set the circular reference now that the object is constructed
		(this as Assignable<typeof this, 'zzz'>).zzz = this;

		this.cell_registry = new Cell_Registry(this);

		this.action_registry = new Action_Registry(options.action_specs || action_specs);
		this.mutations = options.mutations || {};

		// Register cell classes if provided, otherwise use the default
		const cells_to_register = options.cell_classes || cell_classes;
		for (const constructor of Object.values(cells_to_register)) {
			this.cell_registry.register(constructor);
		}

		// Initialize cell collections
		this.time = new Time({zzz: this});
		this.ui = new Ui({zzz: this});
		this.models = new Models({zzz: this});
		this.chats = new Chats({zzz: this});
		this.tapes = new Tapes({zzz: this});
		this.providers = new Providers({zzz: this});
		this.prompts = new Prompts({zzz: this});
		this.bits = new Bits({zzz: this});
		this.diskfiles = new Diskfiles({zzz: this});
		this.actions = new Actions({zzz: this});
		this.socket = new Socket({zzz: this});
		this.url_params = new Url_Params({zzz: this});
		this.capabilities = new Capabilities({zzz: this});

		this.bots = options.bots ?? BOTS_DEFAULT;

		this.api = create_actions_api(this);

		this.api_client = new Api_Client({
			...options.api_client_options, // TODO think about more flexible extension of `Api_Client`
			http_rpc_url: options.http_rpc_url,
			socket: this.socket,
		});

		this.decoders = {
			// TODO do this automatically from the schema?
			ui: (value) => {
				// If ui data is provided, update the existing ui instance
				if (value && typeof value === 'object') {
					this.ui.set_json(value);
				}
				// Always return HANDLED since we manage the ui instance directly
				return HANDLED;
			},
		};

		if (options.providers?.length) {
			this.add_providers(options.providers);
		}

		if (options.models?.length) {
			this.models.add_many(options.models);
		}

		if (options.socket_url) {
			this.socket.connect(options.socket_url);
		}

		this.init();
	}

	/**
	 * Submit a completion request to an AI provider and return a promise for the response
	 */
	async submit_completion(
		prompt: string,
		provider_name: Provider_Name,
		model: string,
		completion_messages?: Array<Completion_Message>,
	): Promise<any> {
		const request_id = create_uuid();

		return this.api.submit_completion({
			completion_request: {
				created: get_datetime_now(),
				request_id,
				provider_name,
				model,
				prompt,
				completion_messages,
			},
		});
	}

	/**
	 * Handles session data loaded from the server.
	 * This method is now simpler as most behavior is handled in mutations.
	 */
	receive_session(data: any): void {
		// Set the zzz_dir property from the session data
		this.zzz_cache_dir = data.zzz_dir;

		// Process files through the diskfiles subsystem
		if (Array.isArray(data.files)) {
			for (const source_file of data.files) {
				this.diskfiles.handle_change({
					change: {type: 'add', path: source_file.id},
					source_file,
				});
			}
		}
	}

	/**
	 * Add multiple providers from JSON configurations
	 */
	add_providers(providers_json: Array<Provider_Json>): void {
		for (const json of providers_json) {
			this.add_provider(json);
		}
	}

	add_provider(provider_json: Provider_Json): void {
		this.providers.add(new Provider({zzz: this, json: provider_json}));
	}

	/**
	 * Lookup a history object for a given diskfile path without creating it.
	 * @returns The history object if it exists, undefined otherwise
	 */
	get_diskfile_history(path: Diskfile_Path): Diskfile_History | undefined {
		return this.diskfile_histories.get(path);
	}

	/**
	 * Create a new history object for a given diskfile path.
	 * @returns The newly created history object
	 */
	create_diskfile_history(path: Diskfile_Path): Diskfile_History {
		const history = new Diskfile_History({zzz: this, json: {path}});
		this.diskfile_histories.set(path, history);
		return history;
	}
}
