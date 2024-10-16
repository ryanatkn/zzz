import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {SvelteMap} from 'svelte/reactivity';
import {create_deferred, type Deferred} from '@ryanatkn/belt/async.js';
import type {Source_File} from '@ryanatkn/gro/filer.js';
import type {Path_Id} from '@ryanatkn/gro/path.js';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';
import {to_array} from '@ryanatkn/belt/array.js';

import {Zzz_Data, type Zzz_Data_Json} from '$lib/zzz_data.svelte.js';
import type {Zzz_Client} from '$lib/zzz_client.js';
import type {Echo_Message, Filer_Change_Message, Receive_Prompt_Message} from '$lib/zzz_message.js';
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

/**
 * The main client. Like a site-wide `app` instance for Zzz.
 * Gettable with `zzz_context.get()` inside a `<Zzz_Root>`.
 */
export class Zzz {
	data: Zzz_Data = $state()!;

	client: Zzz_Client;

	// TODO what APi for these? `Agents` or `Agent_Manager` class?
	// maybe have the source of truth by an array?
	agents: SvelteMap<string, Agent> = new SvelteMap();

	files_by_id: SvelteMap<Path_Id, Source_File> = new SvelteMap();

	echos: Echo_Message[] = $state([]);

	pending_prompts: SvelteMap<string, Deferred<Receive_Prompt_Message>> = new SvelteMap();

	prompt_responses: SvelteMap<string, Receive_Prompt_Message> = new SvelteMap();

	pending_prompts_by_agent: Map<Agent, Receive_Prompt_Message[]> = $derived(
		new Map(
			Array.from(this.agents.values()).map((agent) => [
				agent,
				Array.from(this.prompt_responses.values()).filter((p) => agent.name === p.agent_name),
			]),
		),
	);

	// TODO @many need ids for req/res
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

	async send_prompt(
		text: string,
		agent: Agent | Agent[] = Array.from(this.agents.values()),
	): Promise<Receive_Prompt_Message[]> {
		// TODO need ids, and then the response promise, tracking by text isn't robust to duplicates
		const agents = to_array(agent);

		const responses = await Promise.all(
			Array.from(agents.values()).map(async (agent) => {
				this.client.send({type: 'send_prompt', agent_name: agent.name, text});

				// TODO @many need ids for req/res
				if (agent.name === 'claude') {
					const deferred = create_deferred<Receive_Prompt_Message>();
					const prompt_responses_key = agent.name + '::' + text; // TODO @many leave this messy code until we have message ids and req/res pairs
					this.pending_prompts.set(prompt_responses_key, deferred);
					const response = await deferred.promise;
					console.log(`prompt response`, response);
					this.pending_prompts.delete(prompt_responses_key); // TODO @many need ids for req/res
					return response;
				}

				return null;
			}),
		);

		return responses.filter((r) => !!r); // TODO @many need ids for req/res
	}

	receive_prompt_response(message: Receive_Prompt_Message): void {
		const deferred = this.pending_prompts.get(message.text);
		if (!deferred) {
			console.error('expected pending', message);
			return;
		}
		if (message.data.type !== 'anthropic') {
			// TODO @many need ids for req/res
			console.error('TODO ignoring all but anthropic messages', message);
			return;
		}
		const prompt_responses_key = message.agent_name + '::' + message.text; // TODO @many leave this messy code until we have message ids and req/res pairs
		this.prompt_responses.set(prompt_responses_key, message);
		deferred.resolve(message);
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

	update_file(file_id: Path_Id, contents: string): void {
		const source_file = this.files_by_id.get(file_id);
		if (!source_file) {
			console.error('expected source file', file_id);
			return;
		}

		this.client.send({type: 'update_file', file_id, contents});
	}

	// TODO API? close/open/toggle? just toggle? messages+mutations?
	toggle_main_menu(value = !this.data.show_main_menu): void {
		this.data.show_main_menu = value;
	}
}
