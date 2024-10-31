import type {Agent, Agent_Name} from '$lib/agent.svelte.js';
import type {Completion_Request, Completion_Response} from '$lib/completion.js';

export interface Completion_Threads_Json {
	completion_threads: Completion_Thread_Json[];
}

export interface Completion_Threads_Options {
	agents: Agent[];
}

export interface Completion_Thread_History_Item {
	completion_request: Completion_Request;
	completion_response: Completion_Response;
}

// Common wrapper around a conversation with a group agent.
// Groups history across multiple agents and prompts.
// Other single-word names: Log, History, Session, Logbook, Dialogue, Conversation, Chat, Transcript
// Other names using `Prompt_`: Prompt_Log, Prompt_History, Prompt_Session, Prompt_Logbook, Prompt_Dialogue, Prompt_Conversation, Prompt_Chat, Prompt_Transcript
export class Completion_Threads {
	// TODO maybe a global history?
	// history: Completion_Thread_History_Item[] = $state([]); // TODO does this make sense anymore, to have the full history in addition to the child completion_threads?

	all: Completion_Thread[] = $state([]);

	agents: Agent[] = $state()!;

	constructor({agents}: Completion_Threads_Options) {
		this.agents = agents;
	}

	toJSON(): Completion_Threads_Json {
		return {
			completion_threads: $state.snapshot(this.all),
		};
	}

	receive_completion_response(request: Completion_Request, response: Completion_Response): void {
		// TODO we need a `completion_thread.id` I think, this is hacky
		// TODO multiple? feels like could be more derived, using a `Map` being read from the derived agents from the `history`
		let completion_thread = this.all.find((t) => t.agents_by_name.get(request.agent_name));
		if (!completion_thread) {
			completion_thread = this.create_completion_thread(); // TODO BLOCK instead of creating new completion_threads, should push to its history
		}
		completion_thread.history.push({completion_request: request, completion_response: response}); // TODO call a method?
		console.log(
			`[completion_thread.receive_completion_response]`,
			$state.snapshot(completion_thread),
		);
	}

	create_completion_thread(agents: Agent[] = this.agents): Completion_Thread {
		const completion_thread = new Completion_Thread({agents});
		this.all.push(completion_thread);
		return completion_thread;
	}

	// TODO
	// completion_responses: Receive_Prompt_Message[] = $state([]);

	// TODO efficiently do something like this for fast lookup
	// pending_prompts_by_agent: Map<Agent, Receive_Prompt_Message[]> = $derived(
	// 	new Map(
	// 		this.agents.map((agent) => [
	// 			agent,
	// 			this.completion_responses.filter((p) => agent.name === p.agent_name),
	// 		]),
	// 	),
	// );

	// constructor(options?: {}) {}
}

export interface Completion_Thread_Json {
	history: Completion_Thread_History_Item[];
}

export interface Completion_Thread_Options {
	agents: Agent[];
}

export class Completion_Thread {
	// TODO look up these agents based on all of the agents in `history`
	agents: Agent[] = $state()!; // handles a group conversation

	history: Completion_Thread_History_Item[] = $state([]);

	// TODO move to an `Agents` or `Agent_Manager` class?
	// TODO more efficient data structures?
	agents_by_name: Map<Agent_Name, Agent> = $derived.by(() => {
		const agents_by_name: Map<Agent_Name, Agent> = new Map();
		for (const h of this.history) {
			const {agent_name} = h.completion_request;
			if (agents_by_name.has(agent_name)) {
				continue;
			}
			const agent = this.agents.find((a) => a.name === agent_name);
			if (!agent) {
				console.error('expected to find agent', agent_name);
				continue;
			}
			agents_by_name.set(agent_name, agent);
		}
		console.log(`agents_by_name`, agents_by_name);
		return agents_by_name;
	});

	constructor({agents}: Completion_Thread_Options) {
		this.agents = agents;
		console.log('[completion_thread] creating new', agents);
	}

	// TODO maybe `completion_thread_id` should be the original id of the `request.id`?

	toJSON(): Completion_Thread_Json {
		return {
			history: $state.snapshot(this.history),
		};
	}
}
