import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {create_deferred, type Deferred} from '@ryanatkn/belt/async.js';
import type {Assignable, Class_Constructor} from '@ryanatkn/belt/types.js';
import {z} from 'zod';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';
import {strip_end, strip_start} from '@ryanatkn/belt/string.js';

import type {
	Action_Send_Prompt,
	Action_Completion_Response,
	Action_Client,
	Action_Server,
	Action_Loaded_Session,
} from '$lib/action_types.js';
import {Provider, type Provider_Json} from '$lib/provider.svelte.js';
import type {Provider_Name} from '$lib/provider_types.js';
import {Uuid, get_datetime_now} from '$lib/zod_helpers.js';
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

export const zzz_context = create_context<Zzz>();

export const Zzz_Json = Cell_Json.extend({
	ui: Ui_Json,
});
export type Zzz_Json = z.infer<typeof Zzz_Json>;
export type Zzz_Json_Input = z.input<typeof Zzz_Json>;

// Special options type for Zzz to handle circular reference
export interface Zzz_Options extends Omit<Cell_Options<typeof Zzz_Json>, 'zzz'> {
	zzz?: Zzz; // Make zzz optional for Zzz initialization
	onsend?: (message: Action_Client) => void;
	onreceive?: (message: Action_Server) => void;
	models?: Array<Model_Json>;
	bots?: Zzz_Config['bots'];
	providers?: Array<Provider_Json>;
	cell_classes?: Record<string, Class_Constructor<Cell>>;
	socket_url?: string | null;
}

/**
 * Action with history structure for conversation context.
 * Use explicit union type rather than string to match the expected role values.
 */
export interface Action_With_History {
	role: 'user' | 'system' | 'assistant';
	content: string;
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

	// TODO maybe `tags` is a virtual collection for ergonomics, in that it's all on the cell table unmanaged by the class, it persists nothing on its own but interfaces to the persistent cells

	readonly bots: Zzz_Config['bots']; // TODO @many hacky, rework the bots interface (currently just copies over the config) - the provider should be on the model object, but should models be able to have multiple providers, or do they need unique names? and another field for canonical model name?

	/**
	 * The `zzz_dir` is the path to Zzz's primary directory on the server's filesystem.
	 * The server's `safe_fs` instance restricts operations to this directory.
	 * The value is `undefined` when uninitialized,
	 * `null` when loading, and `''` when disabled or no server.
	 */
	zzz_dir: Zzz_Dir | null | undefined = $state(null);
	/** The `zzz_dir` without the trailing `.zzz/`. Has its own trailing slash. */
	zzz_dir_parent: Diskfile_Path | null | undefined = $derived(
		this.zzz_dir && (strip_end(this.zzz_dir, ZZZ_DIRNAME + '/') as Diskfile_Path), // casting is safe because `Zzz_Dir` extends `Diskfile_Path`
	);
	zzz_dir_pathname: Diskfile_Path | null | undefined = $derived(
		this.zzz_dir &&
			this.zzz_dir_parent &&
			(strip_start(this.zzz_dir, this.zzz_dir_parent) as Diskfile_Path), // casting is safe because `Zzz_Dir` extends `Diskfile_Path`
	);

	// Special property to detect self-reference
	readonly is_zzz: boolean = true;

	// TODO think about how this could be an incremental indexed value - maybe push through indexes rather than using derived signals?
	tags: Set<string> = $derived.by(() => {
		const tag_set: Set<string> = new Set();
		for (const model of this.models.items.by_id.values()) {
			for (const tag of model.tags) {
				tag_set.add(tag);
			}
		}
		return tag_set;
	});

	// Runtime-only state (not serialized)
	readonly pending_prompts: SvelteMap<Uuid, Deferred<Action_Completion_Response>> = new SvelteMap();

	// Store Diskfile_History objects by file path
	readonly diskfile_histories: SvelteMap<Diskfile_Path, Diskfile_History> = new SvelteMap();

	constructor(options: Zzz_Options = EMPTY_OBJECT) {
		// Pass this instance as its own zzz reference
		super(Zzz_Json, options as Zzz_Options & {zzz: Zzz}); // Temporary type assertion, will be fixed after construction

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

	async send_prompt(
		prompt: string,
		provider_name: Provider_Name,
		model: string,
		tape_history?: Array<Action_With_History>,
	): Promise<Action_Completion_Response> {
		const request_id = Uuid.parse(undefined);
		const message: Action_Send_Prompt = {
			id: request_id,
			type: 'send_prompt',
			completion_request: {
				created: get_datetime_now(),
				request_id,
				provider_name,
				model,
				prompt,
				tape_history,
			},
		};
		this.actions.send(message);

		const deferred = create_deferred<Action_Completion_Response>();
		this.pending_prompts.set(message.id, deferred);

		const response = await deferred.promise;

		return response;
	}

	receive_completion_response(message: Action_Completion_Response): void {
		const deferred = this.pending_prompts.get(message.completion_response.request_id);
		if (!deferred) {
			console.error('expected pending', message);
			return;
		}
		deferred.resolve(message);
		this.pending_prompts.delete(message.completion_response.request_id); // deleting intentionally after resolving to maybe avoid a corner case loop of sending the same prompt again
	}

	/**
	 * Handles session data loaded from the server.
	 * Sets the zzz_dir and adds files to diskfiles.
	 */
	receive_session(data: Action_Loaded_Session['data']): void {
		// Set the zzz_dir property from the session data
		this.zzz_dir = data.zzz_dir;

		// Add files from the session data to diskfiles
		for (const source_file of data.files) {
			this.diskfiles.handle_change({
				type: 'filer_change',
				id: Uuid.parse(undefined), // TODO shouldnt need to fake, maybe call an internal method directly? or do we want a single path?
				change: {type: 'add', path: source_file.id},
				source_file,
			});
		}
	}

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
		const history = new Diskfile_History({zzz: this.zzz, json: {path}});
		this.diskfile_histories.set(path, history);
		return history;
	}

	/** See into Zzz's future. */
	futuremode = $state(false);
}
