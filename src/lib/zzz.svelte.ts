import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {create_deferred, type Deferred} from '@ryanatkn/belt/async.js';
import type {Source_File} from '@ryanatkn/gro/filer.js';
import type {Path_Id} from '@ryanatkn/gro/path.js';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

import {Zzz_Data, type Zzz_Data_Json} from '$lib/zzz_data.svelte.js';
import type {Zzz_Client} from '$lib/zzz_client.js';
import type {Filer_Change_Message, Prompt_Response_Message} from '$lib/zzz_message.js';
import type {Agent} from '$lib/agent.svelte.js';

export const zzz_context = create_context<Zzz>();

export interface Zzz_Options {
	agents: Agent[];
	client: Zzz_Client;
	data?: Zzz_Data;
}

export interface Zzz_Json {
	data: Zzz_Data_Json;
}

export class Zzz {
	data: Zzz_Data = $state()!;

	client: Zzz_Client;

	// TODO what APi for these? `Agents` or `Agent_Manager` class?
	agents: SvelteMap<string, Agent> = new SvelteMap();

	files_by_id: SvelteMap<Path_Id, Source_File> = new SvelteMap();

	pending_prompts: SvelteMap<string, Deferred<Prompt_Response_Message>> = new SvelteMap();

	prompt_responses: SvelteMap<string, Prompt_Response_Message> = new SvelteMap();

	pending_prompts_by_agent: Map<Agent, Prompt_Response_Message[]> = $derived(
		new Map(
			Array.from(this.agents.values()).map((agent) => [
				agent,
				Array.from(this.prompt_responses.values()).filter((p) => agent.name === p.agent_name),
			]),
		),
	);
	// TODO BLOCK store state granularly for each agent

	constructor(options: Zzz_Options) {
		const {agents, client, data = new Zzz_Data()} = options;
		for (const agent of agents) this.agents.set(agent.name, agent);
		this.client = client;
		this.data = data;
	}

	toJSON(): Zzz_Json {
		return {
			data: this.data.toJSON(),
		};
	}

	async send_prompt(text: string, agent: Agent): Promise<void> {
		// TODO need ids, and then the response promise, tracking by text isn't robust to duplicates
		this.client.send({type: 'send_prompt', agent_name: agent.name, text});
		const deferred = create_deferred<Prompt_Response_Message>();
		this.pending_prompts.set(text, deferred);
		const response = await deferred.promise;
		console.log(`prompt response`, response);
		this.pending_prompts.delete(text);
	}

	receive_prompt_response(message: Prompt_Response_Message): void {
		const pending = this.pending_prompts.get(message.text);
		if (!pending) {
			console.error('expected pending', message);
			return;
		}
		this.prompt_responses.set(message.text, message);
		pending.resolve(message);
		this.pending_prompts.delete(message.text); // deleting intentionally after resolving to maybe avoid a corner case loop of sending the same prompt again
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
}
