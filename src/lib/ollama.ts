import type ollama from 'ollama/browser';
import type {ListResponse, ModelResponse, ShowResponse} from 'ollama/browser'; // eslint-disable-line no-duplicate-imports
import {BROWSER} from 'esm-env';

import type {Model_Json} from '$lib/model.svelte.js';

export interface Ollama_Model_Info {
	model: ModelResponse;
	metadata: ShowResponse;
}

export interface Ollama_Models_Response {
	model_list: ListResponse;
	model_infos: Array<Ollama_Model_Info>;
}

/** Import `ollama` dynamically for the browser or non-browser environments. */
let ollama_imported: typeof ollama | undefined;

export const import_ollama = async (): Promise<typeof ollama> => {
	if (ollama_imported) return ollama_imported;
	const imported = await (BROWSER ? import('ollama/browser') : import('ollama'));
	ollama_imported = imported.default;
	return ollama_imported;
};

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
		model_list = await (await import_ollama()).list();
	} catch (err) {
		console.log(`failed to call \`ollama.list()\``, err);
	}
	return model_list;
};

export const ollama_list_with_metadata = async (): Promise<Ollama_Models_Response | null> => {
	try {
		const model_list = await ollama_list();
		if (!model_list) return null;

		const ollama = await import_ollama();

		const model_infos = await Promise.all(
			model_list.models.map(async (model) => ({
				model,
				metadata: await ollama.show({model: model.name}),
			})),
		);

		return {model_list, model_infos};
	} catch (err) {
		console.error(err);
		return null;
	}
};

/**
 * Mutates `models` with the Ollama model metadata.
 */
export const merge_ollama_models = (
	models: Array<Model_Json>,
	model_infos: Array<Ollama_Model_Info>,
): Array<Model_Json> => {
	for (const ollama_model_info of model_infos) {
		const {model} = ollama_model_info;
		const existing_index = models.findIndex((m) => m.name === model.name);
		if (existing_index === -1) {
			models.push({
				name: model.name,
				provider_name: 'ollama',
				tags: model.details.families,
				ollama_model_info,
			});
		} else {
			models[existing_index].ollama_model_info = ollama_model_info;
		}
	}

	return models;
};
