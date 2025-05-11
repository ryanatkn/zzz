import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {z} from 'zod';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';
import {strip_end, strip_start} from '@ryanatkn/belt/string.js';
import type {Assignable, Class_Constructor, Omit_Strict} from '@ryanatkn/belt/types.js';

import {
	type Action_Message_From_Client,
	type Action_Message_From_Server,
	action_specs,
} from '$lib/action_collections.js';
import {Provider, type Provider_Json} from '$lib/provider.svelte.js';
import type {Provider_Name} from '$lib/provider_types.js';
import {Uuid, create_uuid, get_datetime_now} from '$lib/zod_helpers.js';
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
import type {Diskfile_Path, Zzz_Dir} from '$lib/diskfile_types.js';
import {ZZZ_DIRNAME} from '$lib/constants.js';
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
import type {JSONRPCMessage} from '$lib/jsonrpc.js';
import type {Action_Method} from '$lib/action_metatypes.js';

export const zzz_context = create_context<Zzz>();

export const Zzz_Json = Cell_Json.extend({
	ui: Ui_Json,
});
export type Zzz_Json = z.infer<typeof Zzz_Json>;
export type Zzz_Json_Input = z.input<typeof Zzz_Json>;

// Special options type for Zzz to handle circular reference
export interface Zzz_Options extends Omit_Strict<Cell_Options<typeof Zzz_Json>, 'zzz'> {
	zzz?: Zzz;
	onsend?: (message: Action_Message_From_Client) => void;
	onreceive?: (message: Action_Message_From_Server) => void;
	models?: Array<Model_Json>;
	bots?: Zzz_Config['bots'];
	providers?: Array<Provider_Json>;
	cell_classes?: Record<string, Class_Constructor<Cell>>;

	/** URL for server communication */
	api_url?: string;

	/** Websocket URL as an optional transport. */
	socket_url?: string | null;

	/** API client options */
	api_client_options?: Api_Client_Options;
}

/**
 * The main client. Like a site-wide `app` instance for Zzz.
 * Gettable with `zzz_context.get()` inside a `<Zzz_Root>`.
 */
export class Zzz extends Cell<typeof Zzz_Json> {
	readonly registry: Cell_Registry;

	// Global cell registry - maps cell id to cell instance
	readonly cells: SvelteMap<Uuid, Cell> = new SvelteMap();

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

	// API client for server communication
	readonly api_client: Api_Client;

	readonly bots: Zzz_Config['bots'];

	/**
	 * Action registry for centralized action specification access.
	 */
	readonly action_registry = new Action_Registry(action_specs);

	/**
	 * The `zzz_dir` is the path to Zzz's primary directory on the server's filesystem.
	 * The server's `safe_fs` instance restricts operations to this directory.
	 * The value is `undefined` when uninitialized,
	 * `null` when loading, and `''` when disabled or no server.
	 */
	zzz_dir: Zzz_Dir | null | undefined = $state(null);

	/** The `zzz_dir` without the trailing `.zzz/`. Has its own trailing slash. */
	zzz_dir_parent: Diskfile_Path | null | undefined = $derived(
		this.zzz_dir && (strip_end(this.zzz_dir, ZZZ_DIRNAME + '/') as Diskfile_Path),
	);

	zzz_dir_pathname: Diskfile_Path | null | undefined = $derived(
		this.zzz_dir &&
			this.zzz_dir_parent &&
			(strip_start(this.zzz_dir, this.zzz_dir_parent) as Diskfile_Path),
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
		const {socket_url, ...rest} = options; // TODO the socket_url made this API awkward
		// Pass this instance as its own zzz reference - casting hacks around the circular reference
		super(Zzz_Json, rest as Zzz_Options & {zzz: Zzz});

		// Set the circular reference now that the object is constructed
		(this as Assignable<typeof this, 'zzz'>).zzz = this;

		// Initialize the registry
		this.registry = new Cell_Registry(this);

		// Register cell classes if provided, otherwise use default cell_classes
		const cells_to_register = options.cell_classes || cell_classes;
		for (const constructor of Object.values(cells_to_register)) {
			this.registry.register(constructor);
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

		// Initialize the API client with the socket instance and message handlers
		this.api_client = new Api_Client({
			zzz: this,
			...options.api_client_options,
			http_url: options.api_url,
			socket: this.socket,
			onreceive: (method, params, id) => {
				// TODO BLOCK Action_Message_From_Server ? parse in dev?
				const message: JSONRPCMessage = {
					id,
					created: get_datetime_now(),
					method,
					params,
				};

				// Handle the message based on its method
				this.api_client.handle_incoming_message(message);

				// Call the provided onreceive handler if available
				if (options.onreceive) {
					options.onreceive(message);
				}
			},
			onsend: (method, params, id) => {
				// TODO BLOCK Action_Message_From_Client ? parse in dev?
				const message: JSONRPCMessage = {
					id: id || create_uuid(),
					created: get_datetime_now(),
					method,
					params: params as any,
				};

				// Call the provided onsend handler if available
				if (options.onsend) {
					options.onsend(message);
				}
			},
		});

		// Set up decoders
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

		// Set up message handlers if provided
		if (options.onsend) {
			this.actions.onsend = options.onsend;
		}
		if (options.onreceive) {
			this.actions.onreceive = options.onreceive;
		}

		// Add providers if provided in options
		if (options.providers?.length) {
			this.add_providers(options.providers);
		}

		// Add models if provided in options
		if (options.models?.length) {
			this.models.add_many(options.models);
		}

		// Initialize socket connection if URL provided
		if (options.socket_url) {
			this.socket.connect(options.socket_url);
		}

		// Call init to complete initialization
		this.init();
	}

	/**
	 * Send an action to the server and get a response
	 */
	async send_action<T = any>(
		method: Action_Method,
		params: Record<string, any> = {},
		id: string = create_uuid(),
	): Promise<T> {
		return this.api_client.send_action<T>(method, params, id);
	}

	/**
	 * Notify the server of an event (no response expected)
	 */
	notify(method: Action_Method, params: Record<string, any> = {}): void {
		this.api_client.notify(method, params);
	}

	/**
	 * Submit a completion request to an AI provider and return a promise for the response
	 */
	async submit_completion<T = any>(
		prompt: string,
		provider_name: Provider_Name,
		model: string,
		completion_messages?: Array<Completion_Message>,
	): Promise<T> {
		const request_id = create_uuid();

		return this.api_client.send_action<T>(
			'submit_completion',
			{
				completion_request: {
					created: get_datetime_now(),
					request_id,
					provider_name,
					model,
					prompt,
					completion_messages,
				},
			},
			request_id,
		);
	}

	/**
	 * Handles session data loaded from the server.
	 * This method is now simpler as most behavior is handled in mutations.
	 */
	receive_session(data: any): void {
		// Set the zzz_dir property from the session data
		this.zzz_dir = data.zzz_dir;

		// Process files through the diskfiles subsystem
		if (Array.isArray(data.files)) {
			for (const source_file of data.files) {
				this.diskfiles.handle_change({
					id: create_uuid(), // TODO shouldnt need to fake, maybe call an internal method directly? or do we want a single path?
					created: get_datetime_now(),
					method: 'filer_change',
					params: {
						change: {type: 'add', path: source_file.id},
						source_file,
					},
				});
			}
		}
	}

	/**
	 * Process completion response - called by mutations
	 */
	receive_completion_response(params: any): void {
		// Implementation can be minimal as behavior is handled in mutations
		console.log('Processing completion response', params.completion_response?.id);
	}

	/**
	 * Add multiple providers from JSON configurations
	 */
	add_providers(providers_json: Array<Provider_Json>): void {
		for (const json of providers_json) {
			const provider = this.registry.maybe_instantiate('Provider', json);
			if (provider) {
				this.add_provider(provider);
			}
		}
	}

	add_provider(provider: Provider): void {
		this.providers.add(provider);
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
