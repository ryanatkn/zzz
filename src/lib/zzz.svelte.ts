import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {create_deferred, type Deferred} from '@ryanatkn/belt/async.js';
import type {Class_Constructor} from '@ryanatkn/belt/types.js';

import {Zzz_Data, type Zzz_Data_Json} from '$lib/zzz_data.svelte.js';
import type {
	Message_Echo,
	Message_Send_Prompt,
	Message_Completion_Response,
} from '$lib/message_types.js';
import {Provider, type Provider_Json} from '$lib/provider.svelte.js';
import type {Provider_Name} from '$lib/provider_types.js';
import {Uuid} from '$lib/uuid.js';
import {Completion_Threads, type Completion_Threads_Json} from '$lib/completion_thread.svelte.js';
import {ollama_list_with_metadata} from '$lib/ollama.js';
import {Models} from '$lib/models.svelte.js';
import {Chats} from '$lib/chats.svelte.js';
import {Providers} from '$lib/providers.svelte.js';
import {Diskfiles} from '$lib/diskfiles.svelte.js';
import {Messages} from '$lib/messages.svelte.js';
import {Model, type Model_Json} from '$lib/model.svelte.js';
import {Cell_Registry} from '$lib/cell_registry.js';
import {Datetime_Now} from '$lib/zod_helpers.js';
import {Prompts} from '$lib/prompts.svelte.js';
import type {Cell} from './cell.svelte.js';
import {Bit} from '$lib/bit.svelte.js';
import {Chat} from '$lib/chat.svelte.js';
import {Diskfile} from '$lib/diskfile.svelte.js';
import {Message} from '$lib/message.svelte.js';
import {Prompt} from '$lib/prompt.svelte.js';
import {Tape} from '$lib/tape.svelte.js';

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
};

// Automatically derive Cell_Registry_Map from cell_classes
export type Cell_Registry_Map = {
	[K in keyof typeof cell_classes]: InstanceType<(typeof cell_classes)[K]>;
};

export const zzz_context = create_context<Zzz>();

export interface Zzz_Options {
	send?: (message: any) => void;
	receive?: (message: any) => void;
	completion_threads?: Completion_Threads;
	data?: Zzz_Data;
	models?: Array<Model_Json>;
	providers?: Array<Provider_Json>;
	cells?: Record<string, Class_Constructor<Cell>>;
}

export interface Zzz_Json {
	data: Zzz_Data_Json;
	completion_threads: Completion_Threads_Json;
}

/**
 * The main client. Like a site-wide `app` instance for Zzz.
 * Gettable with `zzz_context.get()` inside a `<Zzz_Root>`.
 */
export class Zzz {
	data: Zzz_Data;
	readonly registry: Cell_Registry;
	readonly models: Models;
	readonly chats: Chats;
	readonly providers: Providers;
	readonly prompts: Prompts;
	readonly diskfiles: Diskfiles;
	readonly messages: Messages;

	tags: Set<string> = $derived.by(() => new Set(this.models.items.flatMap((m) => m.tags)));

	echos: Array<Message_Echo> = $state([]);
	echos_max_length: number = $state(10);

	// TODO could track this more formally, and add time tracking
	pending_prompts: SvelteMap<Uuid, Deferred<Message_Completion_Response>> = new SvelteMap();

	completion_threads: Completion_Threads;

	capability_ollama: undefined | null | boolean = $state();

	constructor(options: Zzz_Options = {}) {
		// Initialize properties in the correct order
		this.data = options.data ?? new Zzz_Data();
		this.completion_threads = options.completion_threads ?? new Completion_Threads({zzz: this});

		// Initialize the registry
		this.registry = new Cell_Registry(this);

		// Initialize component collections first
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

		// Register cell classes if provided, otherwise use default cell_classes
		const cells_to_register = options.cells || cell_classes;
		for (const constructor of Object.values(cells_to_register)) {
			this.registry.register(constructor);
		}

		// Add providers if provided in options
		if (options.providers?.length) {
			this.add_providers(options.providers);
		}

		// Add models if provided in options
		if (options.models?.length) {
			this.add_models(options.models);
		}
	}

	/**
	 * Register a cell class with the registry
	 */
	register<T extends Cell>(cell_class: Class_Constructor<T>): void {
		this.registry.register(cell_class);
	}

	// TODO BLOCK extend cell so this doesnt exist, automatic from the schema
	toJSON(): Zzz_Json {
		return {
			data: this.data.toJSON(),
			completion_threads: this.completion_threads.toJSON(),
		};
	}

	inited_models: boolean | undefined = $state();

	// TODO maybe make this sync instead of init?
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
			},
		};
		this.messages.send(message);

		const deferred = create_deferred<Message_Completion_Response>();
		this.pending_prompts.set(message.id, deferred);
		const response = await deferred.promise;

		// Ensure the completion response matches the required structure
		if (response.completion_response) {
			// Direct assignment without helper
			this.completion_threads.receive_completion_response(
				message.completion_request,
				response.completion_response,
			);
		} else {
			console.error('Invalid completion response format:', response);
		}

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

	readonly echo_start_times: Map<Uuid, number> = new Map();

	readonly echo_elapsed: SvelteMap<Uuid, number> = new SvelteMap();

	send_echo(data: unknown): void {
		const id = Uuid.parse(undefined);
		const message: Message_Echo = {id, type: 'echo', data};
		this.messages.send(message);
		this.echo_start_times.set(id, Date.now());
		this.echos = [message, ...this.echos.slice(0, this.echos_max_length - 1)];
	}

	receive_echo(message: Message_Echo): void {
		const {id} = message;
		const start_time = this.echo_start_times.get(id);
		if (start_time === undefined) {
			console.error('expected start time', id);
			return;
		}
		this.echo_start_times.delete(id);
		const elapsed = Date.now() - start_time;
		this.echo_elapsed.set(id, elapsed);
	}

	// TODO API? close/open/toggle? just toggle? messages+mutations?
	toggle_main_menu(value = !this.data.show_main_dialog): void {
		this.data.show_main_dialog = value;
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
