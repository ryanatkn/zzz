/**
 * Helper module for safely working with completion responses
 * and handling type compatibility issues.
 */
import type {Provider_Name} from '$lib/provider_types.js';
import type {
	Provider_Data,
	Completion_Response,
	Ollama_Provider_Data,
	Claude_Provider_Data,
	Chatgpt_Provider_Data,
	Gemini_Provider_Data,
	Message_Completion_Response,
} from '$lib/message_types.js';
import {Datetime_Now, Uuid} from '$lib/zod_helpers.js';

/**
 * Extract text content from a completion response based on provider type.
 */
export const to_completion_response_text = (
	completion_response: Completion_Response | null | undefined,
): string | null => {
	if (!completion_response) return null;

	const provider = completion_response.provider_name;
	const {data} = completion_response;

	// Validate provider type matches
	if (data.type !== provider) {
		console.error('Mismatched provider type in completion response', data.type, provider);
		return null;
	}

	// Ensure value exists before trying to access properties
	if (!data.value) {
		console.error('Missing value in completion response data', data);
		return null;
	}

	// TODO avoid casting
	switch (provider) {
		case 'ollama':
			return (data as Ollama_Provider_Data).value?.message?.content || null;

		case 'claude':
			return (data as Claude_Provider_Data).value?.content?.[0]?.text || null;

		case 'chatgpt':
			return (data as Chatgpt_Provider_Data).value?.choices?.[0]?.message?.content || null;

		case 'gemini':
			return (data as Gemini_Provider_Data).value.text || null;

		default:
			console.error('Unknown provider', provider);
			return null;
	}
};

/**
 * Process provider-specific data to ensure it conforms to expected schema.
 */
export const process_provider_data = (
	provider_name: Provider_Name,
	api_response: any,
): Provider_Data => {
	switch (provider_name) {
		case 'ollama':
			return {
				type: 'ollama',
				value: api_response,
			};

		case 'claude':
			return {
				type: 'claude',
				value: api_response,
			};

		case 'chatgpt':
			return {
				type: 'chatgpt',
				value: api_response,
			};

		case 'gemini': {
			// Handle Gemini's special case with function response getters
			return {
				type: 'gemini',
				value: {
					// Extract text immediately from the function to avoid serialization issues
					text:
						typeof api_response.response.text === 'function' ? api_response.response.text() : '',
					candidates: api_response.response.candidates || null,
					function_calls:
						typeof api_response.response.functionCalls === 'function'
							? api_response.response.functionCalls()
							: null,
					prompt_feedback: api_response.response.promptFeedback || null,
					usage_metadata: api_response.response.usageMetadata || null,
				},
			};
		}

		default:
			console.error('Unknown provider', provider_name);
			return {
				type: provider_name as Provider_Name,
				value: api_response,
			};
	}
};

/**
 * Creates a standard completion response object.
 */
export const create_completion_response = (
	request_id: string,
	provider_name: Provider_Name,
	model: string,
	api_response: any,
): Completion_Response => {
	return {
		created: Datetime_Now.parse(undefined),
		request_id: Uuid.parse(request_id),
		provider_name,
		model,
		data: process_provider_data(provider_name, api_response),
	};
};

/**
 * Creates a completion response message.
 */
export const create_completion_response_message = (
	request_id: string,
	provider_name: Provider_Name,
	model: string,
	api_response: any,
): Message_Completion_Response => {
	return {
		id: Uuid.parse(undefined),
		type: 'completion_response',
		completion_response: create_completion_response(request_id, provider_name, model, api_response),
	};
};
