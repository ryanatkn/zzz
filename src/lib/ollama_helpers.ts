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
		tensors: z.array(z.any()).optional(), // TODO maybe strip? is removed atm in `ollama.svelte.ts`
	})
	.passthrough();
export type Ollama_Show_Response = z.infer<typeof Ollama_Show_Response>;

// TODO @many assert type: ModelResponse -- Ollama is bugged, PS response item has additional fields compared to list
export const Ollama_Ps_Response_Item = z
	.object({
		details: Ollama_Model_Details.optional(),
		digest: z.string(),
		expires_at: z.string(), // ISO date string for when the model will be unloaded
		model: z.string(),
		name: z.string(),
		size: z.number(),
		size_vram: z.number(), // Amount of VRAM used by the model
	})
	.passthrough();
export type Ollama_Ps_Response_Item = z.infer<typeof Ollama_Ps_Response_Item>;

// TODO @many assert type: ListResponse (bugged in Ollama, is different for list vs ps)
export const Ollama_Ps_Response = z
	.object({
		models: z.array(Ollama_Ps_Response_Item),
	})
	.passthrough();
export type Ollama_Ps_Response = z.infer<typeof Ollama_Ps_Response>;

// Request schemas
export const Ollama_List_Request = z.void().optional();
export type Ollama_List_Request = z.infer<typeof Ollama_List_Request>;

export const Ollama_Ps_Request = z.void().optional();
export type Ollama_Ps_Request = z.infer<typeof Ollama_Ps_Request>;

export const Ollama_Show_Request = z
	.object({
		model: z.string(),
		system: z.string().optional(),
		template: z.string().optional(),
		options: z.any().optional(), // Partial<Options>
	})
	.passthrough();
export type Ollama_Show_Request = z.infer<typeof Ollama_Show_Request>;

export const Ollama_Pull_Request = z
	.object({
		model: z.string(),
		insecure: z.boolean().optional(),
		stream: z.boolean().optional(),
	})
	.passthrough();
export type Ollama_Pull_Request = z.infer<typeof Ollama_Pull_Request>;

export const Ollama_Push_Request = z
	.object({
		model: z.string(),
		insecure: z.boolean().optional(),
		stream: z.boolean().optional(),
	})
	.passthrough();
export type Ollama_Push_Request = z.infer<typeof Ollama_Push_Request>;

export const Ollama_Create_Request = z
	.object({
		model: z.string(),
		from: z.string().optional(),
		stream: z.boolean().optional(),
		quantize: z.string().optional(),
		template: z.string().optional(),
		license: z.union([z.string(), z.array(z.string())]).optional(),
		system: z.string().optional(),
		parameters: z.record(z.unknown()).optional(),
		messages: z.array(z.any()).optional(), // Array<Message>
		adapters: z.record(z.string()).optional(),
	})
	.passthrough();
export type Ollama_Create_Request = z.infer<typeof Ollama_Create_Request>;

export const Ollama_Delete_Request = z
	.object({
		model: z.string(),
	})
	.passthrough();
export type Ollama_Delete_Request = z.infer<typeof Ollama_Delete_Request>;

export const Ollama_Copy_Request = z
	.object({
		source: z.string(),
		destination: z.string(),
	})
	.passthrough();
export type Ollama_Copy_Request = z.infer<typeof Ollama_Copy_Request>;

/**
 * Extract parameter count from parameter size string like "7B", "13B", etc.
 */
export const extract_parameter_count = (parameter_size: string | undefined): number | undefined => {
	if (!parameter_size) return undefined;
	const match = /^(\d+(?:\.\d+)?)[BM]?$/i.exec(parameter_size);
	if (!match) return undefined;
	const value = parseFloat(match[1]);
	// If it ends with M, convert to billions
	if (parameter_size.toUpperCase().endsWith('M')) {
		return value / 1000;
	}
	return value;
};
