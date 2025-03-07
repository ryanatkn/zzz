import {z} from 'zod';

import {Model_Name, type Model} from '$lib/model.svelte.js';
import {Uuid, Datetime_Now} from '$lib/zod_helpers.js';
import type {Chat_Message} from '$lib/chat_message.svelte.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {cell_array} from '$lib/cell_helpers.js';
import {Cell_Json} from '$lib/cell_types.js';

export const Tape_Json = Cell_Json.extend({
	id: Uuid,
	created: Datetime_Now,
	model_name: Model_Name.default(''), // TODO BLOCK `model_id`?
	chat_messages: cell_array(
		z.array(z.any()).default(() => []),
		'Chat_Message',
	),
});

// TODO BLOCK should tapes be immutable, so the single model makes sense?
// TODO BLOCK I think we need a way to say at each step what the model was?

export type Tape_Json = z.infer<typeof Tape_Json>;

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
