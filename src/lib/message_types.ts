import {z} from 'zod';

import {Diskfile_Change_Type, Source_File, Diskfile_Path} from '$lib/diskfile_types.js';
import {Datetime_Now, Uuid} from '$lib/zod_helpers.js';
import type {Provider_Name} from '$lib/provider_types.js';
import {Cell_Json} from '$lib/cell_types.js';

export const Message_Direction = z.enum(['client', 'server', 'both']);
export type Message_Direction = z.infer<typeof Message_Direction>;

export const Message_Type = z.enum([
	'ping',
	'pong',
	'send_prompt',
	'completion_response',
	'update_diskfile',
	'delete_diskfile',
	'filer_change',
	'load_session',
	'loaded_session',
]);
export type Message_Type = z.infer<typeof Message_Type>;

// Define schema for tape history message
export const Tape_History_Message = z.object({
	role: z.enum(['user', 'system', 'assistant']),
	content: z.string(),
});
export type Tape_History_Message = z.infer<typeof Tape_History_Message>;

// Define explicit interfaces for provider-specific data
export interface Ollama_Provider_Data {
	type: 'ollama';
	value: any; // ChatResponse from ollama - must be required
}

export interface Claude_Provider_Data {
	type: 'claude';
	value: any; // Message from Anthropic - must be required
}

export interface Chatgpt_Provider_Data {
	type: 'chatgpt';
	value: any; // ChatCompletion from OpenAI - must be required
}

export interface Gemini_Provider_Data {
	type: 'gemini';
	value: {
		text: string;
		candidates: any[] | null;
		function_calls: any[] | null;
		prompt_feedback: any | null;
		usage_metadata: any | null;
	};
}

// Union type of all provider data types
export type Provider_Data =
	| Ollama_Provider_Data
	| Claude_Provider_Data
	| Chatgpt_Provider_Data
	| Gemini_Provider_Data;

// Schema validation for provider data
export const Provider_Data_Schema = z.discriminatedUnion('type', [
	z.object({
		type: z.literal('ollama'),
		value: z
			.any()
			.optional()
			.transform((v) => v || {}), // Ensure value exists even if undefined
	}),
	z.object({
		type: z.literal('claude'),
		value: z
			.any()
			.optional()
			.transform((v) => v || {}),
	}),
	z.object({
		type: z.literal('chatgpt'),
		value: z
			.any()
			.optional()
			.transform((v) => v || {}),
	}),
	z.object({
		type: z.literal('gemini'),
		value: z.object({
			text: z.string(),
			candidates: z.array(z.any()).nullable().optional(),
			function_calls: z.array(z.any()).nullable().optional(),
			prompt_feedback: z.any().nullable().optional(),
			usage_metadata: z.any().nullable().optional(),
		}),
	}),
]);

// Define Completion Request and Response schemas
export const Completion_Request = z.object({
	created: Datetime_Now,
	request_id: Uuid,
	provider_name: z.string() as z.ZodType<Provider_Name>,
	model: z.string(),
	prompt: z.string(),
	tape_history: z.array(Tape_History_Message).optional(),
});
export type Completion_Request = z.infer<typeof Completion_Request>;

export const Completion_Response = z.object({
	created: Datetime_Now,
	request_id: Uuid,
	provider_name: z.string() as z.ZodType<Provider_Name>,
	model: z.string(),
	data: Provider_Data_Schema,
});
export type Completion_Response = z.infer<typeof Completion_Response>;

// Base message schema
export const Message_Base = z
	.object({
		id: Uuid,
		type: Message_Type,
	})
	.strict();
export type Message_Base = z.infer<typeof Message_Base>;

// Ping/Pong message schemas
export const Message_Ping = Message_Base.extend({
	type: z.literal('ping'),
}).strict();
export type Message_Ping = z.infer<typeof Message_Ping>;

export const Message_Pong = Message_Base.extend({
	type: z.literal('pong'),
	ping_id: Uuid,
}).strict();
export type Message_Pong = z.infer<typeof Message_Pong>;

// Session related message schemas
export const Message_Load_Session = Message_Base.extend({
	type: z.literal('load_session'),
}).strict();
export type Message_Load_Session = z.infer<typeof Message_Load_Session>;

export const Message_Loaded_Session = Message_Base.extend({
	type: z.literal('loaded_session'),
	data: z
		.object({
			files: z.record(Diskfile_Path, Source_File),
		})
		.strict(),
}).strict();
export type Message_Loaded_Session = z.infer<typeof Message_Loaded_Session>;

// File related message schemas
export const Message_Filer_Change = Message_Base.extend({
	type: z.literal('filer_change'),
	change: z
		.object({
			type: Diskfile_Change_Type,
			path: Diskfile_Path,
		})
		.strict(),
	source_file: Source_File,
}).strict();
export type Message_Filer_Change = z.infer<typeof Message_Filer_Change>;

export const Message_Update_Diskfile = Message_Base.extend({
	type: z.literal('update_diskfile'),
	path: Diskfile_Path,
	contents: z.string(),
}).strict();
export type Message_Update_Diskfile = z.infer<typeof Message_Update_Diskfile>;

export const Message_Delete_Diskfile = Message_Base.extend({
	type: z.literal('delete_diskfile'),
	path: Diskfile_Path,
}).strict();
export type Message_Delete_Diskfile = z.infer<typeof Message_Delete_Diskfile>;

// Completion related message schemas
export const Message_Send_Prompt = Message_Base.extend({
	type: z.literal('send_prompt'),
	completion_request: Completion_Request,
}).strict();
export type Message_Send_Prompt = z.infer<typeof Message_Send_Prompt>;

export const Message_Completion_Response = Message_Base.extend({
	type: z.literal('completion_response'),
	completion_response: Completion_Response,
}).strict();
export type Message_Completion_Response = z.infer<typeof Message_Completion_Response>;

// Union of all client message types
export const Message_Client = z.discriminatedUnion('type', [
	Message_Ping,
	Message_Load_Session,
	Message_Send_Prompt,
	Message_Update_Diskfile,
	Message_Delete_Diskfile,
]);
export type Message_Client = z.infer<typeof Message_Client>;

// Union of all server message types
export const Message_Server = z.discriminatedUnion('type', [
	Message_Pong,
	Message_Loaded_Session,
	Message_Filer_Change,
	Message_Completion_Response,
]);
export type Message_Server = z.infer<typeof Message_Server>;

// TODO BLOCK this name conflicts with the other Message
// Union of all message types
export const Message = z.discriminatedUnion('type', [
	Message_Ping,
	Message_Pong,
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
export const Message_Json = Cell_Json.extend({
	id: Uuid,
	type: Message_Type,
	direction: Message_Direction,
	created: Datetime_Now,
	// Optional fields with proper type checking
	ping_id: Uuid.optional(),
	completion_request: Completion_Request.optional(),
	completion_response: Completion_Response.optional(),
	path: Diskfile_Path.optional(),
	contents: z.string().optional(),
	change: z
		.object({
			type: Diskfile_Change_Type,
			path: Diskfile_Path,
		})
		.strict()
		.optional(),
	source_file: Source_File.optional(),
	data: z.record(z.string(), z.any()).optional(),
}).strict();
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
