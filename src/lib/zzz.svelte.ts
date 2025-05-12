import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {z} from 'zod';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';
import {strip_end, strip_start} from '@ryanatkn/belt/string.js';
import type {Assignable, Class_Constructor, Omit_Strict} from '@ryanatkn/belt/types.js';

import type {
	Action_Message_From_Client,
	Action_Message_From_Server,
} from '$lib/action_collections.js';
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
import {create_mutation_context} from '$lib/mutation.js';
import type {Mutations} from '$lib/action_metatypes.js';
import type {Action_Spec} from '$lib/action_spec.js';

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
	send_mutations?: Mutations;
	receive_mutations?: Mutations;

	/** URL for server communication */
	api_url?: string;

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
	// App-wide cell registry - maps class name to constructor and tracks registered instances
	readonly cell_registry: Cell_Registry;

	/**
	 * Action registry for centralized action specification access.
	 */
	readonly action_registry: Action_Registry;

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
		// Pass this instance as its own zzz reference - casting hacks around the circular reference
		super(Zzz_Json, options as Zzz_Options & {zzz: Zzz});

		// Set the circular reference now that the object is constructed
		(this as Assignable<typeof this, 'zzz'>).zzz = this;

		this.cell_registry = new Cell_Registry(this);

		this.action_registry = new Action_Registry(options.action_specs || []); // making this optional for now, the app will just have no actions

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
		this.actions = new Actions({
			zzz: this,
			onreceive: (action) => {
				// this.api_client.receive_action(action.method, action.params, action.id);
			},
			onsend: (action) => {
				// TODO BLOCK so, "dispatching" an action is probably something we need a concept around,
				// maybe this right here calls into it, the idea being that not all actions are sent to the server,
				// we have local mutations for many of them -- and mutations for now can be centrally defined
				this.api_client.send_action(action.method, action.params, action.id);
			},
		});
		this.socket = new Socket({zzz: this});
		this.url_params = new Url_Params({zzz: this});
		this.capabilities = new Capabilities({zzz: this});

		this.bots = options.bots ?? BOTS_DEFAULT;

		const {send_mutations, receive_mutations} = options;

		this.api_client = new Api_Client({
			...options.api_client_options,
			http_url: options.api_url,
			socket: this.socket,
			// TODO BLOCK @many shouldnt this be a JSONRPCMessage?
			onsend: (message: Action_Message_From_Client) => {
				console.log('[ws] sending message', message);
				// TODO BLOCK Action_Message_From_Client ? parse in dev?
				const m: JSONRPCMessage = {
					id: message.id || create_uuid(),
					created: get_datetime_now(),
					method: message.method,
					params: message.params as any,
				};

				console.log(`constructed m`, m);
				this.socket.send(m); // TODO JSON-RPC

				// TODO dynamic registry? maybe with an API not a plain object?
				const mutation = send_mutations?.[message.method]; // TODO think about before/after
				if (!mutation) {
					// console.warn('unknown message name, ignoring:', message.method, message);
					return; // Ignore messages with no mutations
				}

				const mutation_context = create_mutation_context(
					this,
					message.method,
					message, // For client actions, params are the full message
					undefined, // Result is undefined for sending
				);

				// TODO @many try/catch?
				const result = mutation(mutation_context.ctx as unknown as any); // TODO type ?
				mutation_context.flush_after_mutation();
				return result;
			},
			// TODO BLOCK @many shouldnt this be a JSONRPCMessage?
			onreceive: (message: Action_Message_From_Server) => {
				console.log(`[ws] received message`, message);

				// TODO BLOCK Action_Message_From_Server ? parse in dev?
				const m: JSONRPCMessage = {
					id: message.id,
					created: get_datetime_now(),
					method: message.method,
					params: message.params,
				};

				// Handle the message based on its method
				this.api_client.handle_incoming_message(message);

				const mutation = receive_mutations?.[message.method];
				if (!mutation) {
					// console.warn('unknown message type, ignoring:', message.type, message);
					return; // Ignore messages with no mutations
				}

				const mutation_context = create_mutation_context(
					this,
					message.method,
					message, // For received actions, params are the full message
					// TODO BLOCK delete this?
					{
						ok: true,
						status: 200, // TODO BLOCK @many JSON-RPC need to forward status, use JSON-RPC like MCP
						value: message,
					},
				);

				// TODO @many try/catch?
				const result = mutation(mutation_context.ctx as unknown as any); // TODO type ?
				mutation_context.flush_after_mutation();
				return result;
			},
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
	async submit_completion<T = any>(
		prompt: string,
		provider_name: Provider_Name,
		model: string,
		completion_messages?: Array<Completion_Message>,
	): Promise<T> {
		const request_id = create_uuid();

		// TODO BLOCK `this.actions.send()` vs this
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
