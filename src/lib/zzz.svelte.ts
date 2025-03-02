import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {create_deferred, type Deferred} from '@ryanatkn/belt/async.js';
import type {z} from 'zod';

import {Zzz_Data, type Zzz_Data_Json} from '$lib/zzz_data.svelte.js';
import {
	Api_Message_With_Metadata,
	to_completion_response,
	type Api_Echo_Message,
	type Api_Receive_Prompt_Message,
	type Api_Send_Prompt_Message,
} from '$lib/api.js';
import {Provider, Provider_Name, type Provider_Json} from '$lib/provider.svelte.js';
import {Uuid} from '$lib/uuid.js';
import {Completion_Threads, type Completion_Threads_Json} from '$lib/completion_thread.svelte.js';
import {ollama_list_with_metadata} from '$lib/ollama.js';
import {Models} from '$lib/models.svelte.js';
import {Chats} from '$lib/chats.svelte.js';
import {Providers} from '$lib/providers.svelte.js';
import {Prompts} from '$lib/prompts.svelte.js';
import {Files} from '$lib/files.svelte.js';
import {Messages} from '$lib/messages.svelte.js';
import {Model, type Model_Json} from '$lib/model.svelte.js';
import {Message} from '$lib/message.svelte.js';

export const zzz_context = create_context<Zzz>();

export interface Zzz_Options {
	send?: (message: any) => void;
	receive?: (message: any) => void;
	completion_threads?: Completion_Threads;
	data?: Zzz_Data;
	models?: Array<Model_Json>;
	providers?: Array<Provider_Json>;
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
	data: Zzz_Data = $state()!;

	readonly models = new Models(this);
	readonly chats = new Chats(this);
	readonly providers = new Providers(this);
	readonly prompts = new Prompts(this);
	readonly files = new Files(this);
	readonly messages = new Messages(this);

	// Change tags to use the readonly models instance
	tags: Set<string> = $derived(new Set(this.models.items.flatMap((m) => m.tags)));

	echos: Array<Api_Echo_Message> = $state([]);

	// TODO could track this more formally, and add time tracking
	pending_prompts: SvelteMap<Uuid, Deferred<Api_Receive_Prompt_Message>> = new SvelteMap();

	completion_threads: Completion_Threads = $state()!;

	capability_ollama: undefined | null | boolean = $state();

	constructor(options: Zzz_Options = {}) {
		// Setup message handlers if provided
		if (options.send && options.receive) {
			this.messages.set_handlers(options.send, options.receive);
		}

		this.completion_threads = options.completion_threads ?? new Completion_Threads({zzz: this});
		this.data = options.data ?? new Zzz_Data();

		// Add providers if provided in options
		if (options.providers?.length) {
			this.add_providers(options.providers);
		}

		// Add models if provided in options
		if (options.models?.length) {
			this.add_models(options.models);
		}
	}

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
	): Promise<Api_Receive_Prompt_Message> {
		const request_id = Uuid.parse(undefined);
		const message: Api_Send_Prompt_Message = {
			id: request_id,
			type: 'send_prompt',
			completion_request: {
				created: new Date().toISOString(),
				request_id,
				provider_name,
				model,
				prompt,
			},
		};
		this.messages.send(message);

		const deferred = create_deferred<Api_Receive_Prompt_Message>();
		this.pending_prompts.set(message.id, deferred);
		const response = await deferred.promise;

		// Ensure the completion response matches the required structure
		if (response.completion_response) {
			// Convert the API response to the internal format
			const completion_response = to_completion_response(response.completion_response);
			this.completion_threads.receive_completion_response(
				message.completion_request,
				completion_response,
			);
		} else {
			console.error('Invalid completion response format:', response);
		}

		return response;
	}

	receive_completion_response(message: Api_Receive_Prompt_Message): void {
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
		const message: Api_Echo_Message = {id, type: 'echo', data};
		this.messages.send(message);
		this.echo_start_times.set(id, Date.now());
		this.echos = [message, ...this.echos.slice(0, 9)];
	}

	receive_echo(message: Api_Echo_Message): void {
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
			this.add_provider(this.create_provider(json));
		}
	}

	add_provider(provider: Provider): void {
		this.providers.add(provider);
	}

	// TODO BLOCK what if instead of these methods we had a generic one?
	create_provider(provider_json: Provider_Json): Provider {
		return new Provider({zzz: this, json: provider_json});
	}
	create_model(model_json: Model_Json): Model {
		return new Model({zzz: this, json: model_json});
	}
	create_message(message_json: z.input<typeof Api_Message_With_Metadata>): Message {
		return new Message({zzz: this, json: message_json});
	}
}
