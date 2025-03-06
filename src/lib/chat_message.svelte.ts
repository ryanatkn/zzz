import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Datetime_Now, Uuid} from '$lib/zod_helpers.js';
import {Completion_Request, Completion_Response} from '$lib/message_types.js';

// Define the Chat_Message role type
export const Chat_Message_Role = z.enum(['user', 'assistant', 'system']);
export type Chat_Message_Role = z.infer<typeof Chat_Message_Role>;

// Define the Chat_Message schema
export const Chat_Message_Json = z.object({
	id: Uuid,
	created: Datetime_Now,
	content: z.string(),
	tape_id: Uuid.nullable().optional(),
	role: Chat_Message_Role,
	request: Completion_Request.optional(),
	response: Completion_Response.optional(),
});

export type Chat_Message_Json = z.infer<typeof Chat_Message_Json>;

export interface Chat_Message_Options extends Cell_Options<typeof Chat_Message_Json> {}

export class Chat_Message extends Cell<typeof Chat_Message_Json> {
	id: Uuid = $state()!;
	created: Datetime_Now = $state()!;
	content: string = $state()!;
	tape_id: Uuid | null | undefined = $state();
	role: Chat_Message_Role = $state()!;
	request?: Completion_Request = $state();
	response?: z.infer<typeof Completion_Response> = $state();

	constructor(options: Chat_Message_Options) {
		super(Chat_Message_Json, options);
		this.init();
	}
}

// Helper function to create a new chat message
export const create_chat_message = (
	content: string,
	role: Chat_Message_Role,
	options: Partial<Omit<Chat_Message_Json, 'content' | 'role'>> = {},
	zzz?: any,
): Chat_Message => {
	return new Chat_Message({
		zzz,
		json: {
			content,
			role,
			id: options.id || Uuid.parse(undefined),
			created: options.created || Datetime_Now.parse(undefined),
			tape_id: options.tape_id,
			request: options.request,
			response: options.response,
		},
	});
};
