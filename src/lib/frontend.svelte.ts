import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {z} from 'zod';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';
import type {Assignable, Class_Constructor, Omit_Strict} from '@ryanatkn/belt/types.js';

import {Provider, type Provider_Json_Input} from '$lib/provider.svelte.js';
import type {Provider_Name} from '$lib/provider_types.js';
import {create_uuid, get_datetime_now} from '$lib/zod_helpers.js';
import {Models} from '$lib/models.svelte.js';
import {Chats} from '$lib/chats.svelte.js';
import {Tapes} from '$lib/tapes.svelte.js';
import {Providers} from '$lib/providers.svelte.js';
import {Diskfiles} from '$lib/diskfiles.svelte.js';
import {Actions} from '$lib/actions.svelte.js';
import type {Model_Json_Input} from '$lib/model.svelte.js';
import {Cell_Registry} from '$lib/cell_registry.svelte.js';
import {Prompts} from '$lib/prompts.svelte.js';
import {Bits} from '$lib/bits.svelte.js';
import {Time} from '$lib/time.svelte.js';
import {Ollama} from '$lib/ollama.svelte.js';
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
import {Action_Peer} from '$lib/action_peer.js';
import type {Completion_Message} from '$lib/completion_types.js';
import type {Action_Method, Actions_Api} from '$lib/action_metatypes.js';
import type {Frontend_Action_Handlers} from '$lib/frontend_action_types.js';
import type {Action_Spec_Union} from '$lib/action_spec.js';
import {Action_Inputs, Action_Outputs, action_specs} from '$lib/action_collections.js';
import {create_frontend_actions_api} from '$lib/frontend_actions_api.js';
import {Action_Executor} from '$lib/action_types.js';
import {
	Action_Event_Phase,
	ACTION_EVENT_PHASE_BY_KIND,
	type Action_Event_Environment,
} from '$lib/action_event_types.js';
import {Frontend_Http_Transport} from '$lib/frontend_http_transport.js';
import {Frontend_Websocket_Transport} from '$lib/frontend_websocket_transport.js';

export const frontend_context = create_context<Frontend>();

export const Frontend_Json = Cell_Json.extend({
	ui: Ui_Json.default(() => Ui_Json.parse({})),
	// TODO other state?
});
export type Frontend_Json = z.infer<typeof Frontend_Json>;
export type Frontend_Json_Input = z.input<typeof Frontend_Json>;

// Special options type for Zzz to handle circular reference
export interface Frontend_Options extends Omit_Strict<Cell_Options<typeof Frontend_Json>, 'app'> {
	/** Do not use - optional to avoid circular reference problem. */
	app?: Frontend;
	models?: Array<Model_Json_Input>;
	bots?: Zzz_Config['bots'];
	providers?: Array<Provider_Json_Input>;
	cell_classes?: Record<string, Class_Constructor<Cell>>;
	action_specs?: Array<Action_Spec_Union>;
	action_handlers?: Frontend_Action_Handlers;

	/** URL for server communication */
	http_rpc_url?: string | null;

	/** Websocket URL as an optional transport. */
	socket_url?: string | null;

	/** Additional HTTP headers for requests */
	http_headers?: Record<string, string>;
}

/**
 * The base frontend app, typically used by creating your own `App extends Frontend`.
 * Gettable with `frontend_context.get()` inside a `<Zzz_Root>`.
 */
export class Frontend extends Cell<typeof Frontend_Json> implements Action_Event_Environment {
	readonly executor: Action_Executor = 'frontend';

	/**
	 * App-wide cell registry, maps class names to constructor and tracks registered instances.
	 */
	readonly cell_registry: Cell_Registry;

	readonly action_registry: Action_Registry;
	readonly action_handlers: Frontend_Action_Handlers;
	readonly api: Actions_Api;
	readonly peer: Action_Peer;

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
	readonly ollama: Ollama;

	readonly bots: Zzz_Config['bots'];

	// TODO maybe instead of this pattern with getters/setters, using an encoder?
	#zzz_dir: Zzz_Dir | null | undefined = $state(null);

	/**
	 * The `zzz_dir` is the path to Zzz's primary directory on the server's filesystem.
	 * The server's `scoped_fs` instance restricts operations to this directory.
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

	constructor(options: Frontend_Options = EMPTY_OBJECT) {
		// Pass this instance as its own zzz reference - casting hacks around the circular reference
		super(Frontend_Json, options as Frontend_Options & {app: Frontend});

		// Set the circular reference now that the object is constructed
		(this as Assignable<typeof this, 'app'>).app = this;

		this.cell_registry = new Cell_Registry(this);

		this.action_registry = new Action_Registry(options.action_specs || action_specs);
		this.action_handlers = options.action_handlers || {};

		// Register cell classes if provided, otherwise use the default
		const cells_to_register = options.cell_classes || cell_classes;
		for (const constructor of Object.values(cells_to_register)) {
			this.cell_registry.register(constructor);
		}

		// Initialize cell collections
		this.time = new Time({app: this});
		this.ui = new Ui({app: this});
		this.models = new Models({app: this});
		this.chats = new Chats({app: this});
		this.tapes = new Tapes({app: this});
		this.providers = new Providers({app: this});
		this.prompts = new Prompts({app: this});
		this.bits = new Bits({app: this});
		this.diskfiles = new Diskfiles({app: this});
		this.actions = new Actions({app: this});
		this.socket = new Socket({app: this});
		this.url_params = new Url_Params({app: this});
		this.capabilities = new Capabilities({app: this});
		this.ollama = new Ollama({app: this});

		this.bots = options.bots ?? BOTS_DEFAULT;

		this.api = create_frontend_actions_api(this);

		this.peer = new Action_Peer({environment: this});

		// Set up transports, adding websocket first so it'll be the default
		if (options.socket_url) {
			this.socket.connect(options.socket_url);
			this.peer.transports.register_transport(new Frontend_Websocket_Transport(this.socket));
		}
		if (options.http_rpc_url) {
			this.peer.transports.register_transport(
				new Frontend_Http_Transport(options.http_rpc_url, options.http_headers),
			);
		}

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

		this.init();
	}

	// TODO think about this API, keep it more minimal

	/**
	 * Submit a completion request to an AI provider and return a promise for the response
	 */
	async submit_completion(
		prompt: string,
		provider_name: Provider_Name,
		model: string,
		completion_messages?: Array<Completion_Message>,
	): Promise<ReturnType<typeof this.api.submit_completion>> {
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

	// TODO refactor, probably `app.session`
	receive_session(data: any): void {
		this.zzz_dir = data.zzz_dir;
		this.zzz_cache_dir = data.zzz_cache_dir;

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
	add_providers(providers_json: Array<Provider_Json_Input>): void {
		for (const json of providers_json) {
			this.add_provider(json);
		}
	}

	add_provider(provider_json: Provider_Json_Input): void {
		this.providers.add(new Provider({app: this, json: provider_json}));
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
		const history = new Diskfile_History({app: this, json: {path}});
		this.diskfile_histories.set(path, history);
		return history;
	}

	lookup_action_handler(
		method: Action_Method,
		phase: Action_Event_Phase,
	): ((event: any) => any) | undefined {
		const method_handlers = (this.action_handlers as any)[method];
		if (!method_handlers) return undefined;
		return method_handlers[phase];
	}

	lookup_action_spec(method: Action_Method): Action_Spec_Union | undefined {
		return this.action_registry.spec_by_method.get(method);
	}

	lookup_action_input_schema<T_Method extends Action_Method>(
		method: T_Method,
	): (typeof Action_Inputs)[T_Method] | undefined {
		const spec = this.action_registry.spec_by_method.get(method);
		return spec?.input as any;
	}

	lookup_action_output_schema<T_Method extends Action_Method>(
		method: T_Method,
	): (typeof Action_Outputs)[T_Method] | undefined {
		const spec = this.action_registry.spec_by_method.get(method);
		return spec?.output as any;
	}

	// TODO maybe better type safety here and the `lookup_action_handler` method?
	/**
	 * Check if a phase is valid for a given action method.
	 */
	is_valid_phase_for_method(method: Action_Method, phase: Action_Event_Phase): boolean {
		const spec = this.action_registry.spec_by_method.get(method);
		if (!spec) return false;
		const valid_phases = ACTION_EVENT_PHASE_BY_KIND[spec.kind];
		return valid_phases.includes(phase as never);
	}
}
