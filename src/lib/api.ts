import {z} from 'zod';

import {File_Change_Type} from '$lib/file.schema.js';
import {Uuid} from '$lib/uuid.js';
import {
	Completion_Request,
	Completion_Response_Schema,
	type Completion_Response,
} from '$lib/completion.js';

// Define all message types as literals for better type safety
export const Api_Message_Type = z.enum([
	'echo',
	'load_session',
	'loaded_session',
	'filer_change',
	'send_prompt',
	'completion_response',
	'update_file',
	'delete_file',
]);
export type Api_Message_Type = z.infer<typeof Api_Message_Type>;

// Base schema for all messages
export const Api_Base_Message = z.object({
	id: Uuid,
	type: Api_Message_Type,
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
		files: z.any(), // This would ideally be a Map<Path_Id, Source_File>
	}),
});

// File related message schemas
export const Api_Filer_Change_Message = Api_Base_Message.extend({
	type: z.literal('filer_change'),
	change: z.object({
		type: File_Change_Type,
		path: z.string(),
	}),
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

// Completion related message schemas - Using the placeholder schemas
export const Api_Send_Prompt_Message = Api_Base_Message.extend({
	type: z.literal('send_prompt'),
	completion_request: Completion_Request, // Placeholder schema for validation
});

export const Api_Receive_Prompt_Message = Api_Base_Message.extend({
	type: z.literal('completion_response'),
	completion_response: Completion_Response_Schema, // Placeholder schema for validation
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
export const Api_Message = z.discriminatedUnion('type', [
	Api_Echo_Message,
	Api_Load_Session_Message,
	Api_Loaded_Session_Message,
	Api_Filer_Change_Message,
	Api_Send_Prompt_Message,
	Api_Receive_Prompt_Message,
	Api_Update_File_Message,
	Api_Delete_File_Message,
]);

// Message direction
export const Api_Message_Direction = z.enum(['client', 'server', 'both']);
export type Api_Message_Direction = z.infer<typeof Api_Message_Direction>;

// Message with metadata schema
export const Api_Message_With_Metadata = z.object({
	id: Uuid,
	type: Api_Message_Type,
	direction: Api_Message_Direction,
	created: z.string().datetime(),
	// Optional fields with proper type checking using placeholder schemas
	data: z.any().optional(),
	completion_request: Completion_Request.optional(),
	completion_response: Completion_Response_Schema.optional(),
	file_id: z.string().optional(),
	contents: z.string().optional(),
	change: z
		.object({
			type: File_Change_Type,
			path: z.string(),
		})
		.optional(),
	source_file: z.any().optional(),
});

// Export TypeScript types - use the TypeScript interfaces for completion types
export type Api_Base_Message = z.infer<typeof Api_Base_Message>;
export type Api_Echo_Message = z.infer<typeof Api_Echo_Message>;
export type Api_Load_Session_Message = z.infer<typeof Api_Load_Session_Message>;
export type Api_Loaded_Session_Message = z.infer<typeof Api_Loaded_Session_Message>;
export type Api_Filer_Change_Message = z.infer<typeof Api_Filer_Change_Message>;
export type Api_Update_File_Message = z.infer<typeof Api_Update_File_Message>;
export type Api_Delete_File_Message = z.infer<typeof Api_Delete_File_Message>;
export type Api_Send_Prompt_Message = Omit<
	z.infer<typeof Api_Send_Prompt_Message>,
	'completion_request'
> & {
	completion_request: Completion_Request;
};
export type Api_Receive_Prompt_Message = Omit<
	z.infer<typeof Api_Receive_Prompt_Message>,
	'completion_response'
> & {
	completion_response: Completion_Response;
};
export type Api_Client_Message = z.infer<typeof Api_Client_Message>;
export type Api_Server_Message = z.infer<typeof Api_Server_Message>;
export type Api_Message = z.infer<typeof Api_Message>;
export type Api_Message_With_Metadata = z.infer<typeof Api_Message_With_Metadata> & {
	completion_request?: Completion_Request;
	completion_response?: Completion_Response;
};

// TODO BLOCK these shouldn't exist
// Helper functions remain for API compatibility
export const to_completion_request = (
	api_request: Api_Send_Prompt_Message['completion_request'],
): Completion_Request => {
	return api_request;
};
// TODO BLOCK these shouldn't exist
export const to_completion_response = (
	api_response: Api_Receive_Prompt_Message['completion_response'],
): Completion_Response => {
	return api_response;
};

// TODO refactor this, smells
// Helper function to create a message with metadata
export const create_message_with_metadata = (
	message: Api_Message,
	direction: Api_Message_Direction,
): Api_Message_With_Metadata => {
	return {
		...message,
		direction,
		created: new Date().toISOString(),
	} as Api_Message_With_Metadata;
};
