import ollama, {type ListResponse, type ModelResponse, type ShowResponse} from 'ollama/browser';
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
	parent_model: z.string(),
	format: z.string(),
	family: z.string(),
	families: z.array(z.string()),
	parameter_size: z.string(),
	quantization_level: z.string(),
});
export type Ollama_Model_Details = z.infer<typeof Ollama_Model_Details>;

export const Ollama_List_Data = z.object({
	name: z.string(),
	modified_at: z.string(), // TODO @many transform to Date?
	size: z.number(),
	digest: z.string(),
	details: Ollama_Model_Details.optional(),
});
export type Ollama_List_Data = z.infer<typeof Ollama_List_Data>;

export const Ollama_Details = z.object({
	details: Ollama_Model_Details.optional(),
	modelfile: z.string().optional(),
	template: z.string().optional(),
	system: z.string().optional(),
	license: z.string().optional(),
	model_info: z.any().optional(), // Map<string, any> in the API
	modified_at: z.string().optional(), // TODO @many transform to Date?
});
export type Ollama_Details = z.infer<typeof Ollama_Details>;

// Equivalent to:
// const fetched = await fetch('http://127.0.0.1:11434/api/tags', {
// 	method: 'GET',
// 	mode: 'cors',
// 	headers: {'Content-Type': 'application/json'},
// });
// const json = await fetched.json();
export const ollama_list = async (): Promise<ListResponse | null> => {
	let model_list: ListResponse | null = null;
	try {
		model_list = await ollama.list();
	} catch (error) {
		console.log(`failed to call \`ollama.list()\``, error);
	}
	return model_list;
};

export const ollama_list_with_metadata = async (): Promise<Ollama_Models_Response | null> => {
	try {
		const model_list = await ollama_list();
		if (!model_list) return null;

		const model_infos = await Promise.all(
			model_list.models.map(async (model) => ({
				model,
				metadata: await ollama.show({model: model.name}),
			})),
		);

		return {model_list, model_infos};
	} catch (error) {
		console.error(error);
		return null;
	}
};
