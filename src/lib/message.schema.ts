import {z} from 'zod';

import {Uuid} from '$lib/uuid.js';
import {Provider_Name} from '$lib/provider.schema.js';

export const Api_Message_Direction = z.enum(['inbound', 'outbound']);
export type Api_Message_Direction = z.infer<typeof Api_Message_Direction>;

export const Api_Message_Type = z.enum([
	'echo',
	'send_prompt',
	'completion_response',
	'update_file',
	'delete_file',
	'filer_change',
	'load_session',
	'loaded_session',
]);
export type Api_Message_Type = z.infer<typeof Api_Message_Type>;

// Define base message schema
export const Message_Json_Base = z.object({
	id: Uuid,
	type: Api_Message_Type,
	direction: Api_Message_Direction,
	created: z.string().default(() => new Date().toISOString()),
});

// Schema for completion request data
export const Completion_Request_Json = z.object({
	prompt: z.string(),
	provider_name: Provider_Name,
	model_name: z.string(),
	options: z.record(z.any()).optional(),
});

// Schema for completion response data
export const Completion_Response_Json = z.object({
	text: z.string().optional(),
	data: z.any().optional(),
	raw: z.any().optional(),
});

// Define specific message schemas by type
export const Message_Json = z.discriminatedUnion('type', [
	// Echo message
	Message_Json_Base.extend({
		type: z.literal('echo'),
		data: z.any(),
	}),

	// Send prompt message
	Message_Json_Base.extend({
		type: z.literal('send_prompt'),
		completion_request: Completion_Request_Json,
	}),

	// Completion response message
	Message_Json_Base.extend({
		type: z.literal('completion_response'),
		completion_response: Completion_Response_Json,
	}),

	// Update file message
	Message_Json_Base.extend({
		type: z.literal('update_file'),
		file_id: z.string(),
		contents: z.string(),
	}),

	// Delete file message
	Message_Json_Base.extend({
		type: z.literal('delete_file'),
		file_id: z.string(),
	}),

	// Filer change message
	Message_Json_Base.extend({
		type: z.literal('filer_change'),
		change: z.any(),
		source_file: z.any(),
	}),

	// Load session message
	Message_Json_Base.extend({
		type: z.literal('load_session'),
	}),

	// Loaded session message
	Message_Json_Base.extend({
		type: z.literal('loaded_session'),
		data: z.any(),
	}),
]);

export type Message_Json = z.infer<typeof Message_Json>;
