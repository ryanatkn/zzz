import {z} from 'zod';

import {Uuid} from '$lib/uuid.js';

// Base schema for all messages
export const Api_Base_Message = z.object({
	id: Uuid,
	type: z.string(),
});

// Echo message schema
export const Api_Echo_Message = Api_Base_Message.extend({
	type: z.literal('echo'),
	data: z.any(),
});

// Session related message schemas
export const Api_Load_Session_Message = Api_Base_Message.extend({
	type: z.literal('load_session'),
});

export const Api_Loaded_Session_Message = Api_Base_Message.extend({
	type: z.literal('loaded_session'),
	data: z.object({
		// Can't directly validate Map in Zod, we'll need custom validation
		files: z.any(), // This would ideally be a Map<Path_Id, Source_File>
	}),
});

// File related message schemas
export const Api_Filer_Change_Message = Api_Base_Message.extend({
	type: z.literal('filer_change'),
	change: z.any(), // Watcher_Change
	source_file: z.any(), // Source_File
});

export const Api_Update_File_Message = Api_Base_Message.extend({
	type: z.literal('update_file'),
	file_id: z.string(), // Path_Id
	contents: z.string(),
});

export const Api_Delete_File_Message = Api_Base_Message.extend({
	type: z.literal('delete_file'),
	file_id: z.string(), // Path_Id
});

// Completion related message schemas
export const Api_Send_Prompt_Message = Api_Base_Message.extend({
	type: z.literal('send_prompt'),
	completion_request: z.any(), // Completion_Request
});

export const Api_Receive_Prompt_Message = Api_Base_Message.extend({
	type: z.literal('completion_response'),
	completion_response: z.any(), // Completion_Response
});

// Union of all client message types
export const Api_Client_Message = z.discriminatedUnion('type', [
	Api_Echo_Message,
	Api_Load_Session_Message,
	Api_Send_Prompt_Message,
	Api_Update_File_Message,
	Api_Delete_File_Message,
]);

// Union of all server message types
export const Api_Server_Message = z.discriminatedUnion('type', [
	Api_Echo_Message,
	Api_Loaded_Session_Message,
	Api_Filer_Change_Message,
	Api_Receive_Prompt_Message,
]);

// Union of all message types
export const Api_Message = z.union([Api_Client_Message, Api_Server_Message]);

// Message direction
export const Api_Message_Direction = z.enum(['client', 'server', 'both']);

// Message with metadata
export const Api_Message_With_Metadata = z.object({
	id: Uuid,
	type: z.string(),
	direction: Api_Message_Direction,
	data: z.any(),
	created: z.string().datetime(),
});

// Export TypeScript types derived from the Zod schemas
export type Api_Base_Message = z.infer<typeof Api_Base_Message>;
export type Api_Echo_Message = z.infer<typeof Api_Echo_Message>;
export type Api_Load_Session_Message = z.infer<typeof Api_Load_Session_Message>;
export type Api_Loaded_Session_Message = z.infer<typeof Api_Loaded_Session_Message>;
export type Api_Filer_Change_Message = z.infer<typeof Api_Filer_Change_Message>;
export type Api_Update_File_Message = z.infer<typeof Api_Update_File_Message>;
export type Api_Delete_File_Message = z.infer<typeof Api_Delete_File_Message>;
export type Api_Send_Prompt_Message = z.infer<typeof Api_Send_Prompt_Message>;
export type Api_Receive_Prompt_Message = z.infer<typeof Api_Receive_Prompt_Message>;
export type Api_Client_Message = z.infer<typeof Api_Client_Message>;
export type Api_Server_Message = z.infer<typeof Api_Server_Message>;
export type Api_Message = z.infer<typeof Api_Message>;
export type Api_Message_Direction = z.infer<typeof Api_Message_Direction>;
export type Api_Message_With_Metadata = z.infer<typeof Api_Message_With_Metadata>;

// Legacy type mappings for backward compatibility
export type Base_Message = Api_Base_Message;
export type Echo_Message = Api_Echo_Message;
export type Load_Session_Message = Api_Load_Session_Message;
export type Loaded_Session_Message = Api_Loaded_Session_Message;
export type Filer_Change_Message = Api_Filer_Change_Message;
export type Update_File_Message = Api_Update_File_Message;
export type Delete_File_Message = Api_Delete_File_Message;
export type Send_Prompt_Message = Api_Send_Prompt_Message;
export type Receive_Prompt_Message = Api_Receive_Prompt_Message;
export type Client_Message = Api_Client_Message;
export type Server_Message = Api_Server_Message;
export type Message_Type = Api_Message['type'];
export type Message_Direction = Api_Message_Direction;
export type Message_Json = Api_Message_With_Metadata;

// Helper function to validate messages
export const validate_message = (message: unknown): Api_Message => {
	return Api_Message.parse(message);
};

// Helper function to create a message with metadata
export const create_message_with_metadata = (
	message: Api_Message,
	direction: Api_Message_Direction,
): Api_Message_With_Metadata => {
	return {
		...message,
		direction,
		created: new Date().toISOString(),
	};
};
