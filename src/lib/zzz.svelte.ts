import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {create_deferred, type Deferred} from '@ryanatkn/belt/async.js';
import type {Assignable, Class_Constructor} from '@ryanatkn/belt/types.js';
import {z} from 'zod';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';

import type {
	Message_Send_Prompt,
	Message_Completion_Response,
	Message_Ping,
	Message_Pong,
} from '$lib/message_types.js';
import {Provider, type Provider_Json} from '$lib/provider.svelte.js';
import type {Provider_Name} from '$lib/provider_types.js';
import {Uuid, Datetime_Now} from '$lib/zod_helpers.js';
// import {Completion_Threads, type Completion_Threads_Json} from '$lib/completion_thread.svelte.js';
import {ollama_list_with_metadata} from '$lib/ollama.js';
import {Models} from '$lib/models.svelte.js';
import {Chats} from '$lib/chats.svelte.js';
import {Providers} from '$lib/providers.svelte.js';
import {Diskfiles} from '$lib/diskfiles.svelte.js';
import {Messages} from '$lib/messages.svelte.js';
import {Model, type Model_Json} from '$lib/model.svelte.js';
import {Cell_Registry} from '$lib/cell_registry.svelte.js';
import {Prompts} from '$lib/prompts.svelte.js';
import {Bit} from '$lib/bit.svelte.js';
import {Chat} from '$lib/chat.svelte.js';
import {Diskfile} from '$lib/diskfile.svelte.js';
import {Message} from '$lib/message.svelte.js';
import {Prompt} from '$lib/prompt.svelte.js';
import {Tape} from '$lib/tape.svelte.js';
import {Ui, Ui_Json} from '$lib/ui.svelte.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';

// Define standard cell classes
export const cell_classes = {
	Bit,
	Chat,
	Chats,
	Diskfile,
	Diskfiles,
	Message,
	Messages,
	Model,
	Models,
	Prompt,
	Prompts,
	Provider,
	Providers,
	Tape,
	Ui,
};

// Automatically derive Cell_Registry_Map from cell_classes
export type Cell_Registry_Map = {
	[K in keyof typeof cell_classes]: InstanceType<(typeof cell_classes)[K]>;
};

export const zzz_context = create_context<Zzz>();

// Define the schema for Zzz - essential serializable state
export const Zzz_Json = Cell_Json.extend({
	ui: Ui_Json,
	// completion_threads: Completion_Threads_Json,
});
export type Zzz_Json = z.infer<typeof Zzz_Json>;

// Special options type for Zzz to handle circular reference
export interface Zzz_Options extends Omit<Cell_Options<typeof Zzz_Json>, 'zzz'> {
	zzz?: Zzz; // Make zzz optional for Zzz initialization
	send?: (message: any) => void;
	receive?: (message: any) => void;
	// completion_threads?: Completion_Threads;
	models?: Array<Model_Json>;
	providers?: Array<Provider_Json>;
	cells?: Record<string, Class_Constructor<Cell>>;
}

/**
 * Message with history structure for conversation context.
 * Use explicit union type rather than string to match the expected role values.
 */
export interface Message_With_History {
	role: 'user' | 'system' | 'assistant';
	content: string;
}

/**
 * The main client. Like a site-wide `app` instance for Zzz.
 * Gettable with `zzz_context.get()` inside a `<Zzz_Root>`.
 */
export class Zzz extends Cell<typeof Zzz_Json> {
	readonly registry: Cell_Registry;

	// Cells - these are managed collections that contain the app state
	readonly ui: Ui = $state()!;
	readonly models: Models = $state()!;
	readonly chats: Chats = $state()!;
	readonly providers: Providers = $state()!;
	readonly prompts: Prompts = $state()!;
	readonly diskfiles: Diskfiles = $state()!;
	readonly messages: Messages = $state()!;

	// Special property to detect self-reference
	readonly is_zzz: boolean = $state(true);

	// Derived values
	tags: Set<string> = $derived.by(() => new Set(this.models.items.flatMap((m) => m.tags)));

	// Runtime-only state (not serialized)
	ping_start_times: Map<Uuid, number> = new Map();
	ping_elapsed: SvelteMap<Uuid, number> = new SvelteMap();
	pending_prompts: SvelteMap<Uuid, Deferred<Message_Completion_Response>> = new SvelteMap();
	// completion_threads: Completion_Threads = $state()!;
	capability_ollama: undefined | null | boolean = $state();
	inited_models: boolean | undefined = $state();

	constructor(options: Zzz_Options = EMPTY_OBJECT) {
		// Pass this instance as its own zzz reference
		super(Zzz_Json, {...options, zzz: undefined as any}); // Temporary type assertion, will be fixed after construction

		// Set the circular reference now that the object is constructed
		(this as Assignable<typeof this, 'zzz'>).zzz = this;

		// Initialize the registry
		this.registry = new Cell_Registry(this);

		// Register cell classes if provided, otherwise use default cell_classes
		const cells_to_register = options.cells || cell_classes;
		for (const constructor of Object.values(cells_to_register)) {
			this.registry.register(constructor);
		}

		// Initialize completion_threads - either use provided or create new
		// this.completion_threads = options.completion_threads ?? new Completion_Threads({zzz: this});

		// Initialize cell collections
		this.ui = new Ui({zzz: this});
		this.models = new Models({zzz: this});
		this.chats = new Chats({zzz: this});
		this.providers = new Providers({zzz: this});
		this.prompts = new Prompts({zzz: this});
		this.diskfiles = new Diskfiles({zzz: this});
		this.messages = new Messages({zzz: this});

		// Set up message handlers if provided
		if (options.send && options.receive) {
			this.messages.set_handlers(options.send, options.receive);
		}

		// Add providers if provided in options
		if (options.providers?.length) {
			this.add_providers(options.providers);
		}

		// Add models if provided in options
		if (options.models?.length) {
			this.add_models(options.models);
		}

		// Call init to complete initialization
		this.init();
	}

	/**
	 * Register a cell class with the registry
	 */
	register<T extends Cell>(cell_class: Class_Constructor<T>): void {
		this.registry.register(cell_class);
	}

	async init_models(): Promise<void> {
		this.inited_models = false;

		// First add the ollama models
		this.capability_ollama = null;
		const ollama_models_response = await ollama_list_with_metadata();
		if (!ollama_models_response) {
			this.capability_ollama = false;
			return;
		}

		this.capability_ollama = true;
		this.models.add_ollama_models(ollama_models_response.model_infos);

		this.inited_models = true;
	}

	add_models(models_json: Array<Model_Json>): void {
		for (const model_json of models_json) {
			if (model_json.provider_name === 'ollama') continue; // TODO Skip ollama models added dynamically for now, but refactor this so it doesn't have a special case
			this.models.add(model_json);
		}
	}

	async send_prompt(
		prompt: string,
		provider_name: Provider_Name,
		model: string,
		tape_history?: Array<Message_With_History>,
	): Promise<Message_Completion_Response> {
		const request_id = Uuid.parse(undefined);
		const message: Message_Send_Prompt = {
			id: request_id,
			type: 'send_prompt',
			completion_request: {
				created: Datetime_Now.parse(undefined),
				request_id,
				provider_name,
				model,
				prompt,
				tape_history,
			},
		};
		this.messages.send(message);

		const deferred = create_deferred<Message_Completion_Response>();
		this.pending_prompts.set(message.id, deferred);
		const response = await deferred.promise;

		// Ensure the completion response matches the required structure
		// if (response.completion_response) {
		// Use safe type assertion with null check
		// if (response.completion_response) {
		// this.completion_threads.receive_completion_response(
		// 	message.completion_request,
		// 	response.completion_response,
		// );
		// }
		// } else {
		// 	console.error('Invalid completion response format:', response);
		// }

		return response;
	}

	receive_completion_response(message: Message_Completion_Response): void {
		const deferred = this.pending_prompts.get(message.completion_response.request_id);
		if (!deferred) {
			console.error('expected pending', message);
			return;
		}
		deferred.resolve(message);
		this.pending_prompts.delete(message.completion_response.request_id); // deleting intentionally after resolving to maybe avoid a corner case loop of sending the same prompt again
	}

	/**
	 * Sends a ping to the server and tracks its start time
	 * @param message The text message to include in the ping
	 */
	send_ping(): void {
		const id = Uuid.parse(undefined);
		const ping: Message_Ping = {
			id,
			type: 'ping',
		};

		this.messages.send(ping);
		this.ping_start_times.set(id, performance.now());
	}

	/**
	 * Handle a pong response from the server
	 * @param pong The pong message received
	 */
	receive_pong(pong: Message_Pong): void {
		const ping_id = pong.ping_id;
		const start_time = this.ping_start_times.get(ping_id);

		if (start_time === undefined) {
			console.error('Expected start time for ping', ping_id);
			return;
		}

		this.ping_start_times.delete(ping_id);
		const elapsed = performance.now() - start_time;
		this.ping_elapsed.set(ping_id, elapsed);
	}

	// TODO API? close/open/toggle? just toggle? messages+mutations?
	toggle_main_menu(value = !this.ui.show_main_dialog): void {
		this.ui.show_main_dialog = value;
	}

	add_providers(providers_json: Array<Provider_Json>): void {
		for (const json of providers_json) {
			const provider = this.registry.instantiate('Provider', json);
			if (provider) {
				this.add_provider(provider);
			}
		}
	}

	add_provider(provider: Provider): void {
		this.providers.add(provider);
	}
}
