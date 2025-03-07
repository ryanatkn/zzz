import {z} from 'zod';
import {encode as tokenize} from 'gpt-tokenizer';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Datetime_Now, Uuid} from '$lib/zod_helpers.js';
import {Completion_Request, Completion_Response} from '$lib/message_types.js';
import {Cell_Json} from '$lib/cell_types.js';

// Define the Chat_Message role type
export const Chat_Message_Role = z.enum(['user', 'assistant', 'system']);
export type Chat_Message_Role = z.infer<typeof Chat_Message_Role>;

// Define the Chat_Message schema
export const Chat_Message_Json = Cell_Json.extend({
	id: Uuid,
	created: Datetime_Now,
	content: z.string(), // TODO BLOCK instead of this should it be just the tape, which has the list of bits? (normalized data, so we're not duplicating content in storage across cells) and content here is a runtime derived property?
	tape_id: Uuid.nullable().optional(),
	role: Chat_Message_Role,
	request: Completion_Request.optional(),
	response: Completion_Response.optional(),
});

export type Chat_Message_Json = z.infer<typeof Chat_Message_Json>;

export interface Chat_Message_Options extends Cell_Options<typeof Chat_Message_Json> {}

export class Chat_Message extends Cell<typeof Chat_Message_Json> {
	content: string = $state()!; // TODO BLOCK should this reference bits? (a message could be an array of bits and/or text?) when a tape gets copied, should the chat messages be copied too?
	tape_id: Uuid | null | undefined = $state();
	role: Chat_Message_Role = $state()!;
	request?: Completion_Request = $state();
	response?: z.infer<typeof Completion_Response> = $state();

	length: number = $derived(this.content.length);
	tokens: Array<number> = $derived(tokenize(this.content));
	token_count: number = $derived(this.tokens.length);

	constructor(options: Chat_Message_Options) {
		super(Chat_Message_Json, options);
		this.init();
	}
}

// Helper function to create a new chat message
export const create_chat_message = (
	content: string,
	role: Chat_Message_Role,
	options?: Partial<Omit<Chat_Message_Json, 'content' | 'role'>>,
	zzz?: any,
): Chat_Message => {
	return new Chat_Message({
		zzz,
		json: {
			content,
			role,
			id: options?.id || Uuid.parse(undefined),
			created: options?.created || Datetime_Now.parse(undefined),
			tape_id: options?.tape_id,
			request: options?.request,
			response: options?.response,
		},
	});
};
