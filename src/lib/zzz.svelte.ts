import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {create_deferred, type Deferred} from '@ryanatkn/belt/async.js';
import type {Source_File} from '@ryanatkn/gro/filer.js';
import type {Path_Id} from '@ryanatkn/gro/path.js';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';
import {to_array} from '@ryanatkn/belt/array.js';

import {Zzz_Data, type Zzz_Data_Json} from '$lib/zzz_data.svelte.js';
import type {Zzz_Client} from '$lib/zzz_client.js';
import type {
	Echo_Message,
	Filer_Change_Message,
	Receive_Prompt_Message,
	Send_Prompt_Message,
} from '$lib/zzz_message.js';
import type {Agent} from '$lib/agent.svelte.js';
import {random_id, type Id} from '$lib/id.js';

export const zzz_context = create_context<Zzz>();

export interface Zzz_Options {
	agents: Agent[];
	client: Zzz_Client;
	data?: Zzz_Data;
}

export interface Zzz_Json {
	data: Zzz_Data_Json;
}

/**
 * The main client. Like a site-wide `app` instance for Zzz.
 * Gettable with `zzz_context.get()` inside a `<Zzz_Root>`.
 */
export class Zzz {
	data: Zzz_Data = $state()!;

	client: Zzz_Client;

	// TODO what APi for these? `Agents` or `Agent_Manager` class?
	// maybe have the source of truth by an array?
	agents: Agent[] = $state([]);

	files_by_id: SvelteMap<Path_Id, Source_File> = new SvelteMap();

	echos: Echo_Message[] = $state([]);

	// TODO could track this more formally, and add time tracking
	pending_prompts: SvelteMap<Id, Deferred<Receive_Prompt_Message>> = new SvelteMap();
	// TODO generically track req/res pairs
	prompt_requests: SvelteMap<Id, {request: Send_Prompt_Message; response: Receive_Prompt_Message}> =
		new SvelteMap();

	prompt_responses: Receive_Prompt_Message[] = $state([]);

	pending_prompts_by_agent: Map<Agent, Receive_Prompt_Message[]> = $derived(
		new Map(
			this.agents.map((agent) => [
				agent,
				this.prompt_responses.filter((p) => agent.name === p.agent_name),
			]),
		),
	);

	// TODO BLOCK store state granularly for each agent

	constructor(options: Zzz_Options) {
		const {agents, client, data = new Zzz_Data()} = options;
		this.agents.push(...agents);
		this.client = client;
		this.data = data;
	}

	toJSON(): Zzz_Json {
		return {
			data: this.data.toJSON(),
		};
	}

	async send_prompt(
		text: string,
		agent: Agent | Agent[] = Array.from(this.agents.values()),
	): Promise<Receive_Prompt_Message[]> {
		// TODO need ids, and then the response promise, tracking by text isn't robust to duplicates
		const agents = to_array(agent);

		const responses = await Promise.all(
			Array.from(agents.values()).map(async (agent) => {
				const message: Send_Prompt_Message = {
					id: random_id(),
					type: 'send_prompt',
					agent_name: agent.name,
					text,
				};
				this.client.send(message);

				const deferred = create_deferred<Receive_Prompt_Message>();
				this.pending_prompts.set(message.id, deferred); // TODO roundabout way to get req/res
				const response = await deferred.promise;
				console.log(`prompt response`, response);
				this.prompt_requests.set(message.id, {request: message, response});
				return response;
			}),
		);

		return responses;
	}

	receive_prompt_response(message: Receive_Prompt_Message): void {
		const deferred = this.pending_prompts.get(message.request_id);
		if (!deferred) {
			console.error('expected pending', message);
			return;
		}
		this.prompt_responses.push(message);
		deferred.resolve(message);
		this.pending_prompts.delete(message.request_id); // deleting intentionally after resolving to maybe avoid a corner case loop of sending the same prompt again
	}

	receive_filer_change(message: Filer_Change_Message): void {
		const {change, source_file} = message;
		switch (change.type) {
			case 'add':
			case 'update':
			case 'delete': {
				this.files_by_id.set(source_file.id, source_file);
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

	// TODO API? close/open/toggle? just toggle? messages+mutations?
	toggle_main_menu(value = !this.data.show_main_menu): void {
		this.data.show_main_menu = value;
	}
}
