import {z} from 'zod';

import {Uuid} from '$lib/uuid.js';
import {Diskfile_Change_Type} from '$lib/diskfile_types.js';
import {Completion_Request, Completion_Response} from '$lib/completion.js';
import {Datetime_Now} from '$lib/zod_helpers.js';

// Direction enum
export const Message_Direction = z.enum(['client', 'server', 'both']);
export type Message_Direction = z.infer<typeof Message_Direction>;

// Message type enum
export const Message_Type = z.enum([
	'echo',
	'send_prompt',
	'completion_response',
	'update_diskfile',
	'delete_diskfile',
	'filer_change',
	'load_session',
	'loaded_session',
]);
export type Message_Type = z.infer<typeof Message_Type>;

// Base message schema
export const Message_Base = z.object({
	id: Uuid,
	type: Message_Type,
});
export type Message_Base = z.infer<typeof Message_Base>;

// Echo message schema
export const Message_Echo = Message_Base.extend({
	type: z.literal('echo'),
	data: z.any(),
});
export type Message_Echo = z.infer<typeof Message_Echo>;

// Session related message schemas
export const Message_Load_Session = Message_Base.extend({
	type: z.literal('load_session'),
});
export type Message_Load_Session = z.infer<typeof Message_Load_Session>;

export const Message_Loaded_Session = Message_Base.extend({
	type: z.literal('loaded_session'),
	data: z.object({
		files: z.any(), // This would ideally be a Map<Path_Id, Source_File>
	}),
});
export type Message_Loaded_Session = z.infer<typeof Message_Loaded_Session>;

// File related message schemas
export const Message_Filer_Change = Message_Base.extend({
	type: z.literal('filer_change'),
	change: z.object({
		type: Diskfile_Change_Type,
		path: z.string(),
	}),
	source_file: z.any(), // Source_File
});
export type Message_Filer_Change = z.infer<typeof Message_Filer_Change>;

export const Message_Update_Diskfile = Message_Base.extend({
	type: z.literal('update_diskfile'),
	file_id: z.string(), // Path_Id
	contents: z.string(),
});
export type Message_Update_Diskfile = z.infer<typeof Message_Update_Diskfile>;

export const Message_Delete_Diskfile = Message_Base.extend({
	type: z.literal('delete_diskfile'),
	file_id: z.string(), // Path_Id
});
export type Message_Delete_Diskfile = z.infer<typeof Message_Delete_Diskfile>;

// Completion related message schemas
export const Message_Send_Prompt = Message_Base.extend({
	type: z.literal('send_prompt'),
	completion_request: Completion_Request,
});
export type Message_Send_Prompt = z.infer<typeof Message_Send_Prompt>;

export const Message_Completion_Response = Message_Base.extend({
	type: z.literal('completion_response'),
	completion_response: Completion_Response,
});
export type Message_Completion_Response = z.infer<typeof Message_Completion_Response>;

// Union of all client message types
export const Message_Client = z.discriminatedUnion('type', [
	Message_Echo,
	Message_Load_Session,
	Message_Send_Prompt,
	Message_Update_Diskfile,
	Message_Delete_Diskfile,
]);
export type Message_Client = z.infer<typeof Message_Client>;

// Union of all server message types
export const Message_Server = z.discriminatedUnion('type', [
	Message_Echo,
	Message_Loaded_Session,
	Message_Filer_Change,
	Message_Completion_Response,
]);
export type Message_Server = z.infer<typeof Message_Server>;

// Union of all message types
export const Message = z.discriminatedUnion('type', [
	Message_Echo,
	Message_Load_Session,
	Message_Loaded_Session,
	Message_Filer_Change,
	Message_Send_Prompt,
	Message_Completion_Response,
	Message_Update_Diskfile,
	Message_Delete_Diskfile,
]);
export type Message = z.infer<typeof Message>;

// Message with metadata schema
export const Message_Json = z.object({
	id: Uuid,
	type: Message_Type,
	direction: Message_Direction,
	created: Datetime_Now,
	// Optional fields with proper type checking
	data: z.any().optional(),
	completion_request: Completion_Request.optional(),
	completion_response: Completion_Response.optional(),
	file_id: z.string().optional(),
	contents: z.string().optional(),
	change: z
		.object({
			type: Diskfile_Change_Type,
			path: z.string(),
		})
		.optional(),
	source_file: z.any().optional(),
});
export type Message_Json = z.infer<typeof Message_Json>;

// Helper function to create a message with json representation
export const create_message_json = (
	message: Message,
	direction: Message_Direction,
): Message_Json => {
	return {
		...message,
		direction,
		created: Datetime_Now.parse(undefined),
	} as Message_Json;
};
