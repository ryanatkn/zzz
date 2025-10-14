import {z} from 'zod';

/** See `app.providers.names` for the available names at runtime. */
export const Provider_Name = z.enum(['ollama', 'claude', 'chatgpt', 'gemini']);
export type Provider_Name = z.infer<typeof Provider_Name>;

// Provider-specific data schemas
export const Provider_Data_Ollama = z.strictObject({
	type: z.literal('ollama'),
	value: z.any().optional().default({}),
});
export type Provider_Data_Ollama = z.infer<typeof Provider_Data_Ollama>;

export const Provider_Data_Claude = z.strictObject({
	type: z.literal('claude'),
	value: z.any().optional().default({}),
});
export type Provider_Data_Claude = z.infer<typeof Provider_Data_Claude>;

export const Provider_Data_Chatgpt = z.strictObject({
	type: z.literal('chatgpt'),
	value: z.any().optional().default({}),
});
export type Provider_Data_Chatgpt = z.infer<typeof Provider_Data_Chatgpt>;

export const Provider_Data_Gemini = z.strictObject({
	type: z.literal('gemini'),
	value: z.strictObject({
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

export const PROVIDER_ERROR_NEEDS_API_KEY = 'needs API key';
export const PROVIDER_ERROR_NOT_INSTALLED = 'not installed';

export const Provider_Status = z.discriminatedUnion('available', [
	z.strictObject({
		name: z.string(),
		available: z.literal(true),
		checked_at: z.number(),
	}),
	z.strictObject({
		name: z.string(),
		available: z.literal(false),
		error: z.string(),
		checked_at: z.number(),
	}),
]);
export type Provider_Status = z.infer<typeof Provider_Status>;
