import {z} from 'zod';

/** See `app.providers.names` for the available names at runtime. */
export const Provider_Name = z.enum(['ollama', 'claude', 'chatgpt', 'gemini']);
export type Provider_Name = z.infer<typeof Provider_Name>;

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
