import type {Receive_Prompt_Message, Send_Prompt_Message} from '$lib/zzz_message.js';
import type {Agent, Agent_Name} from './agent.svelte.js';

export interface Tapes_Json {
	tapes: Tape_Json[];
}

export interface Tapes_Options {
	agents: Agent[];
}

export interface Tape_History_Item {
	request: Send_Prompt_Message;
	response: Receive_Prompt_Message;
}

// Common wrapper around a conversation with a group agent.
// Groups history across multiple agents and prompts.
// Other single-word names: Log, History, Session, Logbook, Dialogue, Conversation, Chat, Transcript
// Other names using `Prompt_`: Prompt_Log, Prompt_History, Prompt_Session, Prompt_Logbook, Prompt_Dialogue, Prompt_Conversation, Prompt_Chat, Prompt_Transcript
export class Tapes {
	// TODO maybe a global history?
	// history: Tape_History_Item[] = $state([]); // TODO does this make sense anymore, to have the full history in addition to the child tapes?

	all: Tape[] = $state([]);

	agents: Agent[] = $state()!;

	constructor({agents}: Tapes_Options) {
		this.agents = agents;
	}

	toJSON(): Tapes_Json {
		return {
			tapes: $state.snapshot(this.all),
		};
	}

	receive_prompt_response(request: Send_Prompt_Message, response: Receive_Prompt_Message): void {
		// TODO we need a `tape.id` I think, this is hacky
		// TODO multiple? feels like could be more derived, using a `Map` being read from the derived agents from the `history`
		let tape = this.all.find((t) => t.agents_by_name.get(request.agent_name));
		if (!tape) {
			this.all.push((tape = new Tape({agents: this.agents}))); // TODO BLOCK instead of creating new tapes, should push to its history
		}
		tape.history.push({request, response}); // TODO call a method?
		console.log(`[tape.receive_prompt_response] tape`, $state.snapshot(tape));
	}

	// TODO
	// prompt_responses: Receive_Prompt_Message[] = $state([]);

	// TODO efficiently do something like this for fast lookup
	// pending_prompts_by_agent: Map<Agent, Receive_Prompt_Message[]> = $derived(
	// 	new Map(
	// 		this.agents.map((agent) => [
	// 			agent,
	// 			this.prompt_responses.filter((p) => agent.name === p.agent_name),
	// 		]),
	// 	),
	// );

	// constructor(options?: {}) {}
}

export interface Tape_Json {
	history: Tape_History_Item[];
}

export interface Tape_Options {
	agents: Agent[];
}

export class Tape {
	// TODO look up these agents based on all of the agents in `history`
	agents: Agent[] = $state()!; // handles a group conversation

	history: Tape_History_Item[] = $state([]);

	// TODO move to an `Agents` or `Agent_Manager` class?
	// TODO more efficient data structures?
	agents_by_name: Map<Agent_Name, Agent> = $derived.by(() => {
		const agents_by_name: Map<Agent_Name, Agent> = new Map();
		for (const h of this.history) {
			const {agent_name} = h.request;
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

	constructor({agents}: Tape_Options) {
		this.agents = agents;
		console.log('[tape] creating new tape', agents);
	}

	// TODO maybe `tape_id` should be the original id of the `request.id`?

	toJSON(): Tape_Json {
		return {
			history: $state.snapshot(this.history),
		};
	}
}
