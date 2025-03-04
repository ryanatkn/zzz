import type {Provider_Name} from '$lib/provider_types.js';
import type {Provider} from '$lib/provider.svelte.js';
import type {Completion_Request, Completion_Response} from '$lib/completion.js';
import type {Zzz} from '$lib/zzz.svelte.js';

export interface Completion_Threads_Json {
	completion_threads: Array<Completion_Thread_Json>;
}

export interface Completion_Threads_Options {
	zzz: Zzz;
}

export interface Completion_Thread_History_Item {
	completion_request: Completion_Request;
	completion_response: Completion_Response;
}

// Common wrapper around a conversation with a group provider.
// Groups history across multiple providers and prompts.
// Other single-word names: Log, History, Session, Logbook, Dialogue, Conversation, Chat, Transcript
// Other names using `Prompt_`: Prompt_Log, Prompt_History, Prompt_Session, Prompt_Logbook, Prompt_Dialogue, Prompt_Conversation, Prompt_Chat, Prompt_Transcript
export class Completion_Threads {
	// TODO maybe a global history?
	// history: Completion_Thread_History_Item[] = $state([]); // TODO does this make sense anymore, to have the full history in addition to the child completion_threads?

	all: Array<Completion_Thread> = $state([]);

	zzz: Zzz;

	constructor({zzz}: Completion_Threads_Options) {
		this.zzz = zzz;
	}

	toJSON(): Completion_Threads_Json {
		return {
			completion_threads: $state.snapshot(this.all),
		};
	}

	receive_completion_response(request: Completion_Request, response: Completion_Response): void {
		// TODO we need a `completion_thread.id` I think, this is hacky
		// TODO multiple? feels like could be more derived, using a `Map` being read from the derived providers from the `history`
		let completion_thread = this.all.find((t) => t.providers_by_name.get(request.provider_name));
		if (!completion_thread) {
			completion_thread = this.create_completion_thread(); // TODO BLOCK instead of creating new completion_threads, should push to its history
		}
		completion_thread.history.push({completion_request: request, completion_response: response}); // TODO call a method?
		console.log(
			`[completion_thread.receive_completion_response]`,
			$state.snapshot(completion_thread),
		);
	}

	create_completion_thread(): Completion_Thread {
		const completion_thread = new Completion_Thread({zzz: this.zzz});
		this.all.push(completion_thread);
		return completion_thread;
	}

	// TODO
	// completion_responses: Receive_Prompt_Message[] = $state([]);

	// TODO efficiently do something like this for fast lookup
	// pending_prompts_by_provider: Map<Provider, Receive_Prompt_Message[]> = $derived(
	// 	new Map(
	// 		this.providers.map((provider) => [
	// 			provider,
	// 			this.completion_responses.filter((p) => provider.name === p.provider_name),
	// 		]),
	// 	),
	// );

	// constructor(options?: {}) {}
}

export interface Completion_Thread_Json {
	history: Array<Completion_Thread_History_Item>;
}

export interface Completion_Thread_Options {
	zzz: Zzz;
}

export class Completion_Thread {
	zzz: Zzz;

	history: Array<Completion_Thread_History_Item> = $state([]);

	// TODO move to an `Providers` or `Provider_Manager` class?
	// TODO more efficient data structures?
	providers_by_name: Map<Provider_Name, Provider> = $derived.by(() => {
		const providers_by_name: Map<Provider_Name, Provider> = new Map();
		for (const h of this.history) {
			const {provider_name} = h.completion_request;
			if (providers_by_name.has(provider_name)) {
				continue;
			}
			const provider = this.zzz.providers.find_by_name(provider_name);
			if (!provider) {
				console.error('expected to find provider', provider_name);
				continue;
			}
			providers_by_name.set(provider_name, provider);
		}
		// console.log(`providers_by_name`, providers_by_name);
		return providers_by_name;
	});

	constructor({zzz}: Completion_Thread_Options) {
		this.zzz = zzz;
	}

	// TODO maybe `completion_thread_id` should be the original id of the `request.id`?

	toJSON(): Completion_Thread_Json {
		return {
			history: $state.snapshot(this.history),
		};
	}
}
