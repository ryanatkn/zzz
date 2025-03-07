import {encode as tokenize} from 'gpt-tokenizer';

import {type Model} from '$lib/model.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import type {Chat_Message} from '$lib/chat_message.svelte.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Tape_Json} from '$lib/tape_types.js';
import {render_tape} from '$lib/tape_helpers.js';

export interface Tape_Options extends Cell_Options<typeof Tape_Json> {}

/**
 * A tape is a linear sequence of chat messages that maintains a chronological
 * record of interactions between the user and the AI.
 */
export class Tape extends Cell<typeof Tape_Json> {
	model_name: string = $state()!;
	model: Model = $derived.by(() => {
		const model = this.zzz.models.find_by_name(this.model_name);
		if (!model) throw Error(`Model "${this.model_name}" not found`); // TODO do this differently?
		return model;
	});
	chat_messages: Array<Chat_Message> = $state([]); // TODO @many incrementally update with a helper class
	chat_messages_by_id: Map<Uuid, Chat_Message> = $derived(
		new Map(this.chat_messages.map((m) => [m.id, m])),
	); // TODO @many incrementally update with a helper class

	content: string = $derived(render_tape(this.chat_messages));
	length: number = $derived(this.content.length);
	tokens: Array<number> = $derived(tokenize(this.content));
	token_count: number = $derived(this.tokens.length);

	constructor(options: Tape_Options) {
		super(Tape_Json, options);
		this.init();
	}

	/**
	 * Add a chat message to this tape.
	 */
	add_chat_message(chat_message: Chat_Message): void {
		this.chat_messages.push(chat_message);
	}
}
