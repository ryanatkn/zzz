import {z} from 'zod';

import {Model_Name, type Model} from '$lib/model.svelte.js';
import {Uuid} from '$lib/uuid.js';
import type {Chat_Message} from '$lib/chat.svelte.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';

export const Tape_Json = z
	.object({
		id: Uuid,
		model_name: Model_Name.default(''), // TODO BLOCK `model_id`?
		messages: z.array(z.any()).default(() => []),
	})
	.default(() => ({}));

export type Tape_Json = z.infer<typeof Tape_Json>;

export interface Tape_Options extends Cell_Options<typeof Tape_Json> {
	model: Model;
}

export class Tape extends Cell<typeof Tape_Json> {
	id: Uuid = $state()!;
	model: Model;
	messages: Array<Chat_Message> = $state([]);

	constructor(options: Tape_Options) {
		super(Tape_Json, options);
		this.model = options.model;
		this.init();
	}

	// TODO BLOCK @many shouldn't exist, need to somehow know to only use the id instead of `$state.snapshot(thing)`
	override to_json(): z.output<typeof Tape_Json> {
		return {
			id: this.id,
			model_name: this.model.name,
			messages: this.messages,
		};
	}

	add_message(message: Chat_Message): void {
		this.messages.push(message);
	}
}
