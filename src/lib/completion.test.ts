// @vitest-environment jsdom
import {test, expect} from 'vitest';
import {to_completion_response_text, ensure_valid_response} from '$lib/completion.js';
import {Uuid} from '$lib/uuid.js';
import {Datetime_Now} from '$lib/zod_helpers.js';
import type {Provider_Name} from '$lib/provider_types.js';

test('to_completion_response_text - handles null response', () => {
	expect(to_completion_response_text(null)).toBeNull();
});

test('to_completion_response_text - extracts text from ollama response', () => {
	const response = {
		created: Datetime_Now.parse(undefined),
		request_id: Uuid.parse(undefined),
		provider_name: 'ollama' as Provider_Name, // Cast as Provider_Name
		model: 'llama3.2',
		data: {
			type: 'ollama',
			value: {
				message: {
					content: 'Hello, world!',
				},
			},
		},
	};

	expect(to_completion_response_text(response)).toBe('Hello, world!');
});

test('ensure_valid_response - handles invalid response', () => {
	expect(ensure_valid_response(null)).toBeNull();
	expect(ensure_valid_response({})).toBeNull();
	expect(ensure_valid_response({data: {}})).toBeNull();
});
