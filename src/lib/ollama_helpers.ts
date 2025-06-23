import ollama from 'ollama/browser';
import type {ListResponse, ModelResponse, ShowResponse} from 'ollama/browser'; // eslint-disable-line no-duplicate-imports

export const OLLAMA_URL = 'http://127.0.0.1:11434'; // TODO config

export interface Ollama_Model_Info {
	model: ModelResponse;
	metadata: ShowResponse;
}

export interface Ollama_Models_Response {
	model_list: ListResponse;
	model_infos: Array<Ollama_Model_Info>;
}

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
