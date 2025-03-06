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
		// If no conversation ID, create one for the first message in a conversation
		if (!message.conversation_id) {
			const existingConversation = this.get_active_conversation_id();
			if (existingConversation) {
				message.conversation_id = existingConversation;
			} else {
				// Start a new conversation
				message.conversation_id = Uuid.parse(undefined);
			}
		}
		this.messages.push(message);
	}

	get_active_conversation_id(): Uuid | null {
		// Get the last message's conversation ID, if any
		const lastMessage = this.messages[this.messages.length - 1];
		return lastMessage?.conversation_id || null;
	}

	get_active_conversation_messages(): Array<Chat_Message> {
		const activeConversationId = this.get_active_conversation_id();
		if (!activeConversationId) return this.messages;

		return this.messages.filter(
			(m) => m.conversation_id === activeConversationId || !m.conversation_id,
		);
	}
}
