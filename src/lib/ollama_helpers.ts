import {z} from 'zod';

export const OLLAMA_URL = 'http://127.0.0.1:11434'; // TODO config

// Defining these Ollama schemas gives us better error messages and checks,
// and there are currently some mistakes in its types.
// They use `passthrough` to allow additional properties and
// are generally used for DEV-only parsing checks, with the parsed result discarded.

// TODO @many assert type: StatusResponse
export const Ollama_Status_Response = z
	.object({
		status: z.string(),
	})
	.passthrough();
export type Ollama_Status_Response = z.infer<typeof Ollama_Status_Response>;

// TODO @many assert type: ProgressResponse
export const Ollama_Progress_Response = z
	.object({
		status: z.string(),
		digest: z.string().optional(),
		total: z.number().optional(),
		completed: z.number().optional(),
	})
	.passthrough();
export type Ollama_Progress_Response = z.infer<typeof Ollama_Progress_Response>;

// TODO @many assert type: ModelDetails
export const Ollama_Model_Details = z
	.object({
		families: z.array(z.string()),
		family: z.string(),
		format: z.string(),
		parameter_size: z.string(),
		parent_model: z.string(),
		quantization_level: z.string(),
	})
	.passthrough();
export type Ollama_Model_Details = z.infer<typeof Ollama_Model_Details>;

// TODO BLOCK fix this with `ps`, it probably shouldn't return `ListResponse` in Ollama
// TODO @many assert type: ModelResponse
export const Ollama_List_Response_Item = z
	.object({
		details: Ollama_Model_Details.optional(),
		digest: z.string(),
		// TODO @many Ollama bug - is this ever returned? marked as required in the types but not showing up - and is the type a string like elsewhere?
		// expires_at: Date;
		model: z.string(),
		modified_at: z.string(), // TODO @many Ollama bug - says Date but is a string
		name: z.string(),
		size: z.number(),
		// TODO @many Ollama bug - is this ever returned? marked as required in the types but not showing up
		// size_vram: number;
	})
	.passthrough();
export type Ollama_List_Response_Item = z.infer<typeof Ollama_List_Response_Item>;

// TODO @many assert type: ListResponse
export const Ollama_List_Response = z
	.object({
		models: z.array(Ollama_List_Response_Item),
	})
	.passthrough();
export type Ollama_List_Response = z.infer<typeof Ollama_List_Response>;

// TODO @many assert type: ShowResponse
export const Ollama_Show_Response = z
	.object({
		capabilities: z.array(z.string()).optional(),
		details: Ollama_Model_Details.optional(),
		license: z.string().optional(),
		model_info: z.any().optional(), // Map<string, any> in the API
		modelfile: z.string().optional(),
		modified_at: z.string().optional(), // TODO @many Ollama bug - says Date but is a string
		template: z.string().optional(),
		tensors: z.array(z.any()).optional(), // TODO maybe strip?
	})
	.passthrough();
export type Ollama_Show_Response = z.infer<typeof Ollama_Show_Response>;
