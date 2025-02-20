import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {create_deferred, type Deferred} from '@ryanatkn/belt/async.js';
import type {Source_File} from '@ryanatkn/gro/filer.js';
import type {Path_Id} from '@ryanatkn/gro/path.js';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';
import type {ModelResponse} from 'ollama/browser';

import {Zzz_Data, type Zzz_Data_Json} from '$lib/zzz_data.svelte.js';
import type {Zzz_Client} from '$lib/zzz_client.js';
import type {
	Echo_Message,
	Filer_Change_Message,
	Receive_Prompt_Message,
	Send_Prompt_Message,
} from '$lib/zzz_message.js';
import type {Provider, Provider_Name} from '$lib/provider.svelte.js';
import {random_id, type Id} from '$lib/id.js';
import {Completion_Threads, type Completion_Threads_Json} from '$lib/completion_thread.svelte.js';
import type {Model} from '$lib/model.svelte.js';

export const zzz_context = create_context<Zzz>();

export interface Zzz_Options {
	providers: Array<Provider>;
	models: Array<Model>;
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
	data: Zzz_Data = $state()!;

	client: Zzz_Client;

	// TODO what APi for these? `Providers` or `Provider_Manager` class?
	// maybe have the source of truth by an array?
	providers: Array<Provider> = $state([]);

	models: Array<Model> = $state([]);

	files_by_id: SvelteMap<Path_Id, Source_File> = new SvelteMap();

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
		const {providers, models, client, data = new Zzz_Data()} = options;
		this.providers.push(...providers);
		this.models.push(...models);
		this.client = client;
		this.completion_threads = options.completion_threads ?? new Completion_Threads({providers});
		this.data = data;
	}

	toJSON(): Zzz_Json {
		return {
			data: this.data.toJSON(),
			completion_threads: this.completion_threads.toJSON(),
		};
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

	receive_filer_change(message: Filer_Change_Message): void {
		const {change, source_file} = message;
		switch (change.type) {
			case 'add':
			case 'update': {
				this.files_by_id.set(source_file.id, source_file);
				break;
			}
			case 'delete': {
				this.files_by_id.delete(source_file.id);
				break;
			}
			default:
				throw new Unreachable_Error(change.type);
		}
	}

	echo_start_times: Map<Id, number> = new Map();

	echo_elapsed: SvelteMap<Id, number> = new SvelteMap();

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

	update_file(file_id: Path_Id, contents: string): void {
		const source_file = this.files_by_id.get(file_id);
		if (!source_file) {
			console.error('expected source file', file_id);
			return;
		}

		this.client.send({id: random_id(), type: 'update_file', file_id, contents});
	}

	delete_file(file_id: Path_Id): void {
		const source_file = this.files_by_id.get(file_id);
		if (!source_file) {
			console.error('expected source file', file_id);
			return;
		}
		// TODO BLOCK this isn't removing it from the `/files` list

		this.client.send({id: random_id(), type: 'delete_file', file_id});
	}

	// TODO API? close/open/toggle? just toggle? messages+mutations?
	toggle_main_menu(value = !this.data.show_main_dialog): void {
		this.data.show_main_dialog = value;
	}

	add_ollama_models(models: Array<ModelResponse>): void {
		for (const model of models) {
			// TODO BLOCK ?
			// this.models.push(new Model({data: model}));
		}
	}
}
