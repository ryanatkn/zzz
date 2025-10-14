import {z} from 'zod';
import type {Async_Status} from '@ryanatkn/belt/async.js';

import type {Model} from '$lib/model.svelte.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import {get_datetime_now, Uuid} from '$lib/zod_helpers.js';
import {Thread} from '$lib/thread.svelte.js';
import {reorder_list} from '$lib/list_helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {get_unique_name, estimate_token_count} from '$lib/helpers.js';
import {Completion_Request} from '$lib/completion_types.js';
import {render_message_with_role} from '$lib/thread_helpers.js';

const Chat_View_Mode = z.enum(['simple', 'multi']).default('simple');
export type Chat_View_Mode = z.infer<typeof Chat_View_Mode>;

export const Chat_Json = Cell_Json.extend({
	name: z.string().default(''),
	thread_ids: z.array(Uuid).default(() => []),
	main_input: z.string().default(''),
	view_mode: Chat_View_Mode,
	selected_thread_id: Uuid.nullable().default(null),
}).meta({cell_class_name: 'Chat'});
export type Chat_Json = z.infer<typeof Chat_Json>;
export type Chat_Json_Input = z.input<typeof Chat_Json>;

export interface Chat_Options extends Cell_Options<typeof Chat_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Chat extends Cell<typeof Chat_Json> {
	name: string = $state()!;
	thread_ids: Array<Uuid> = $state()!;
	main_input: string = $state()!;
	view_mode: Chat_View_Mode = $state()!;
	selected_thread_id: Uuid | null = $state()!;

	readonly main_input_length: number = $derived(this.main_input.length);
	readonly main_input_token_count: number = $derived(estimate_token_count(this.main_input));

	// TODO look into using an index for this, incremental from `this.thread_ids`
	readonly threads: Array<Thread> = $derived.by(() => {
		const result: Array<Thread> = [];
		const {by_id} = this.app.threads.items;

		for (const id of this.thread_ids) {
			const thread = by_id.get(id);
			if (thread) {
				result.push(thread);
			}
		}

		return result;
	});

	readonly enabled_threads = $derived(this.threads.filter((t) => t.enabled)); // TODO indexed collection, also disabled variant?

	readonly selected_thread: Thread | undefined = $derived(
		this.selected_thread_id ? this.app.threads.items.by_id.get(this.selected_thread_id) : undefined,
	);

	readonly current_thread: Thread | undefined = $derived(
		this.selected_thread || this.enabled_threads[0],
	);

	// TODO refactor
	init_name_status: Async_Status = $state('initial');

	constructor(options: Chat_Options) {
		super(Chat_Json, options);
		this.init();
	}

	add_thread(model: Model, select?: boolean): void {
		const thread = new Thread({app: this.app, json: {model_name: model.name}});
		this.app.threads.add_thread(thread);
		this.thread_ids.push(thread.id);
		if (select || (!this.selected_thread_id && this.thread_ids.length === 1)) {
			this.select_thread(thread.id);
		}
	}

	add_threads_by_model_tag(tag: string): void {
		const models = this.app.models.filter_by_tag(tag);
		for (const model of models) {
			this.add_thread(model);
		}
	}

	remove_thread(id: Uuid): void {
		const index = this.thread_ids.findIndex((thread_id) => thread_id === id);
		if (index !== -1) {
			this.thread_ids.splice(index, 1);
		}
	}

	remove_threads(ids: Array<Uuid>): void {
		this.thread_ids = this.thread_ids.filter((t) => !ids.includes(t));
	}

	remove_threads_by_model_tag(tag: string): void {
		for (const thread of this.threads.filter((t) => t.model.tags.includes(tag))) {
			this.remove_thread(thread.id);
		}
	}

	remove_all_threads(): void {
		this.thread_ids.length = 0;
	}

	async send_to_all(content: string): Promise<void> {
		await Promise.all(
			// TODO batched endpoint
			this.enabled_threads.map((thread) => this.send_to_thread(thread.id, content)),
		);
	}

	async send_to_thread(thread_id: Uuid, content: string): Promise<void> {
		const thread = this.app.threads.items.by_id.get(thread_id);
		if (!thread) return;

		this.updated = get_datetime_now(); // TODO @many probably rely on the db to bump `updated`

		const assistant_turn = await thread.send_message(content);

		// TODO maybe make the above return a result, so we can get better error handling, or maybe do that through the error handlers for the action?
		// Only attempt auto-naming if turn was created (not skipped due to unavailable provider)
		if (assistant_turn) {
			void this.init_name_from_turns(content, assistant_turn.content);
		}
	}

	// TODO needs to be reworked (maybe accept an array of messages?), also shouldn't clobber any user-assigned names
	/**
	 * Uses an LLM to name the chat based on the user input and AI response.
	 * Ignores failures and retries on next intention.
	 */
	async init_name_from_turns(user_content: string, assistant_content: string): Promise<void> {
		// TODO better abstraction for this kind of thing including de-duping the request,
		// returning the current promise, see `Request_Tracker/Request_Tracker_Item`
		if (this.init_name_status !== 'initial') return;

		// Check if namerbot's provider is available before attempting to name
		const namerbot_model = this.app.models.find_by_name(this.app.bots.namerbot);
		if (!namerbot_model) {
			console.warn(
				`[chat.init_name_from_turns] namerbot model not found: ${this.app.bots.namerbot}`,
			);
			return; // Stay in 'initial' state for retry later
		}

		const provider_status = this.app.lookup_provider_status(namerbot_model.provider_name);
		if (provider_status && !provider_status.available) {
			console.warn(
				`[chat.init_name_from_turns] namerbot provider '${namerbot_model.provider_name}' unavailable, skipping auto-naming`,
			);
			return; // Stay in 'initial' state for retry later
		}

		this.init_name_status = 'pending';

		// TODO refactor
		let p = `Output a short title for this chat conversation with no commentary,
			for this chat content, use lowercase words (unless proper nouns) with no punctuation:\n\n`;

		// TODO not hardcoded?
		p += render_message_with_role('user', user_content);
		p += '\n\n' + render_message_with_role('assistant', assistant_content);

		try {
			// TODO configure this utility LLM (roles?), and set the output token count from config as well
			const name_response = await this.app.api.completion_create({
				// TODO @many should parsing be automatic, so the types change to schema input types? makes sense yeah?
				// I think perf is maybe the main reason not to do this?
				completion_request: Completion_Request.parse({
					provider_name: namerbot_model.provider_name,
					model: this.app.bots.namerbot,
					prompt: p,
				}),
			});

			if (!name_response.ok) {
				this.init_name_status = 'initial'; // ignore failures
				console.error('failed to infer a name for a chat', name_response.error);
				return;
			}

			const {completion_response} = name_response.value;

			const response_text = to_completion_response_text(completion_response) || '';

			if (!response_text) {
				console.error('unknown inference failure', name_response);
				this.init_name_status = 'initial'; // ignore failures
				return;
			}

			this.init_name_status = 'success';
			if (response_text !== this.name) {
				this.name = get_unique_name(response_text, this.app.chats.items_by_name);
			}
		} catch (error) {
			this.init_name_status = 'initial'; // ignore failures
			console.error('failed to infer a name for a chat', error);
		}
	}

	/**
	 * Reorder threads by moving from one index to another
	 */
	select_thread(thread_id: Uuid | null): void {
		this.selected_thread_id = thread_id;
	}

	reorder_threads(from_index: number, to_index: number): void {
		reorder_list(this.thread_ids, from_index, to_index);
	}
}

export const Chat_Schema = z.instanceof(Chat);
