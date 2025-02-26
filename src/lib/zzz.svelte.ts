import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {create_deferred, type Deferred} from '@ryanatkn/belt/async.js';

import {Zzz_Data, type Zzz_Data_Json} from '$lib/zzz_data.svelte.js';
import type {Zzz_Client} from '$lib/zzz_client.js';
import type {Echo_Message, Receive_Prompt_Message, Send_Prompt_Message} from '$lib/zzz_message.js';
import {Provider, type Provider_Json, type Provider_Name} from '$lib/provider.svelte.js';
import {random_id, type Id} from '$lib/id.js';
import {Completion_Threads, type Completion_Threads_Json} from '$lib/completion_thread.svelte.js';
import {ollama_list_with_metadata} from '$lib/ollama.js';
import {zzz_config} from '$lib/zzz_config.js';
import {Models} from '$lib/models.svelte.js';
import {Chats} from '$lib/chats.svelte.js';
import {Providers} from '$lib/providers.svelte.js';
import {Prompts} from '$lib/prompts.svelte.js';
import {Files} from '$lib/files.svelte.js';

export const zzz_context = create_context<Zzz>();

export interface Zzz_Options {
	client: Zzz_Client;
	completion_threads?: Completion_Threads;
	data?: Zzz_Data;
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
	data: Zzz_Data = $state()!; // TODO stable ref or state?

	readonly client: Zzz_Client;

	readonly models = new Models(this);
	readonly chats = new Chats(this);
	readonly providers = new Providers(this);
	readonly prompts = new Prompts(this);
	readonly files = new Files(this);

	// Change tags to use the readonly models instance
	tags: Set<string> = $derived(new Set(this.models.items.flatMap((m) => m.tags)));

	echos: Array<Echo_Message> = $state([]);

	// TODO could track this more formally, and add time tracking
	pending_prompts: SvelteMap<Id, Deferred<Receive_Prompt_Message>> = new SvelteMap();
	// TODO generically track req/res pairs
	// completion_requests: SvelteMap<Id, {request: Send_Prompt_Message; response: Receive_Prompt_Message}> =
	// 	new SvelteMap();

	completion_threads: Completion_Threads = $state()!; // TODO should this be an option?

	capability_ollama: undefined | null | boolean = $state(); // TODO probably rethink - `null` means pending, `undefined` means uninitialized/not yet checked

	// TODO store state granularly for each provider

	constructor(options: Zzz_Options) {
		this.client = options.client;
		this.completion_threads = options.completion_threads ?? new Completion_Threads({zzz: this});
		this.data = options.data ?? new Zzz_Data();
		// TODO move this? options? same with models below?
		this.add_providers(zzz_config.providers);
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

		// Add non-ollama models
		// TODO maybe instead of `zzz_config.models` make an option, but set that as the default
		for (const model of zzz_config.models) {
			if (model.provider_name === 'ollama') continue;
			this.models.add(model);
		}

		this.inited_models = true;
	}

	async send_prompt(
		prompt: string,
		provider_name: Provider_Name,
		model: string,
	): Promise<Receive_Prompt_Message> {
		const request_id = random_id();
		const message: Send_Prompt_Message = {
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
		this.client.send(message);

		const deferred = create_deferred<Receive_Prompt_Message>();
		this.pending_prompts.set(message.id, deferred); // TODO roundabout way to get req/res
		const response = await deferred.promise;
		this.completion_threads.receive_completion_response(
			message.completion_request,
			response.completion_response,
		);
		return response;
	}

	receive_completion_response(message: Receive_Prompt_Message): void {
		const deferred = this.pending_prompts.get(message.completion_response.request_id);
		if (!deferred) {
			console.error('expected pending', message);
			return;
		}
		deferred.resolve(message);
		this.pending_prompts.delete(message.completion_response.request_id); // deleting intentionally after resolving to maybe avoid a corner case loop of sending the same prompt again
	}

	readonly echo_start_times: Map<Id, number> = new Map();

	readonly echo_elapsed: SvelteMap<Id, number> = new SvelteMap();

	send_echo(data: unknown): void {
		const id = random_id();
		const message: Echo_Message = {id, type: 'echo', data};
		this.client.send(message);
		this.echo_start_times.set(id, Date.now());
		this.echos = [message, ...this.echos.slice(0, 9)];
	}

	receive_echo(message: Echo_Message): void {
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
			this.add_provider(new Provider({zzz: this, json}));
		}
	}

	add_provider(provider: Provider): void {
		this.providers.add(provider);
	}
}
