import type {ListResponse, ModelResponse, ShowResponse} from 'ollama/browser';
import {z} from 'zod';

export const OLLAMA_URL = 'http://127.0.0.1:11434'; // TODO config

export interface Ollama_Model_Info {
	model: ModelResponse;
	metadata: ShowResponse;
}

export interface Ollama_Models_Response {
	model_list: ListResponse;
	model_infos: Array<Ollama_Model_Info>;
}

// TODO BLOCK fix with Ollama types
// Ollama-specific schemas
export const Ollama_Model_Details = z.object({
	families: z.array(z.string()),
	family: z.string(),
	format: z.string(),
	parameter_size: z.string(),
	parent_model: z.string(),
	quantization_level: z.string(),
});
export type Ollama_Model_Details = z.infer<typeof Ollama_Model_Details>;

export const Ollama_List_Response_Item = z.object({
	details: Ollama_Model_Details.optional(),
	digest: z.string(),
	model: z.string(),
	modified_at: z.string(), // TODO @many transform to Date?
	name: z.string(),
	size: z.number(),
});
export type Ollama_List_Response_Item = z.infer<typeof Ollama_List_Response_Item>;

export const Ollama_List_Response = z.object({
	models: z.array(Ollama_List_Response_Item),
});
export type Ollama_List_Response = z.infer<typeof Ollama_List_Response>;

export const Ollama_Show_Response = z.object({
	capabilities: z.array(z.string()).optional(),
	details: Ollama_Model_Details.optional(),
	license: z.string().optional(),
	model_info: z.any().optional(), // Map<string, any> in the API
	modelfile: z.string().optional(),
	modified_at: z.string().optional(), // TODO @many transform to Date?
	template: z.string().optional(),
	tensors: z.array(z.any()).optional(),
});
export type Ollama_Show_Response = z.infer<typeof Ollama_Show_Response>;
