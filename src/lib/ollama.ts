import type ollama from 'ollama/browser';
import type {ListResponse} from 'ollama';
import {BROWSER} from 'esm-env';

export const import_ollama = async (): Promise<typeof ollama> => {
	const imported = await (BROWSER ? import('ollama') : import('ollama/browser'));
	return imported.default;
};

// Equivalent to:
// const fetched = await fetch('http://127.0.0.1:11434/api/tags', {
// 	method: 'GET',
// 	mode: 'cors',
// 	headers: {'Content-Type': 'application/json'},
// });
// const json = await fetched.json();
export const ollama_list = async (): Promise<ListResponse | null> => {
	let list_response: ListResponse | null = null;
	try {
		list_response = await (await import_ollama()).list();
	} catch (err) {
		console.log(`failed to call \`ollama.list()\``, err);
	}
	return list_response;
};
