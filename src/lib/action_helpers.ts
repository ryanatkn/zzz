import {z} from 'zod';

import {Datetime_Now, Uuid_With_Default} from '$lib/zod_helpers.js';
import {Provider_Name} from '$lib/provider_types.js';

// Action types and schemas following Model Context Protocol patterns

export const Action_Direction = z.enum(['client', 'server', 'both']);
export type Action_Direction = z.infer<typeof Action_Direction>;

export const Tape_Role = z.enum(['user', 'system', 'assistant']);
export type Tape_Role = z.infer<typeof Tape_Role>;

export const Tape_Message = z.object({
	role: Tape_Role,
	content: z.string(),
});
export type Tape_Message = z.infer<typeof Tape_Message>;

// Provider-specific data schemas
export const Provider_Data_Ollama = z.object({
	type: z.literal('ollama'),
	value: z.any().optional().default({}),
});
export type Provider_Data_Ollama = z.infer<typeof Provider_Data_Ollama>;

export const Provider_Data_Claude = z.object({
	type: z.literal('claude'),
	value: z.any().optional().default({}),
});
export type Provider_Data_Claude = z.infer<typeof Provider_Data_Claude>;

export const Provider_Data_Chatgpt = z.object({
	type: z.literal('chatgpt'),
	value: z.any().optional().default({}),
});
export type Provider_Data_Chatgpt = z.infer<typeof Provider_Data_Chatgpt>;

export const Provider_Data_Gemini = z.object({
	type: z.literal('gemini'),
	value: z.object({
		text: z.string(),
		candidates: z.array(z.any()).nullable().optional(),
		function_calls: z.array(z.any()).nullable().optional(),
		prompt_feedback: z.any().nullable().optional(),
		usage_metadata: z.any().nullable().optional(),
	}),
});
export type Provider_Data_Gemini = z.infer<typeof Provider_Data_Gemini>;

export const Provider_Data_Schema = z.discriminatedUnion('type', [
	Provider_Data_Ollama,
	Provider_Data_Claude,
	Provider_Data_Chatgpt,
	Provider_Data_Gemini,
]);
export type Provider_Data = z.infer<typeof Provider_Data_Schema>;

// Request and response schemas
export const Completion_Request = z
	.object({
		created: Datetime_Now,
		request_id: Uuid_With_Default,
		provider_name: Provider_Name,
		model: z.string(),
		prompt: z.string(),
		tape_messages: z.array(Tape_Message).optional(),
	})
	.strict();
export type Completion_Request = z.infer<typeof Completion_Request>;

export const Completion_Response = z
	.object({
		created: Datetime_Now,
		request_id: Uuid_With_Default,
		provider_name: Provider_Name,
		model: z.string(),
		data: Provider_Data_Schema,
	})
	.strict();
export type Completion_Response = z.infer<typeof Completion_Response>;
