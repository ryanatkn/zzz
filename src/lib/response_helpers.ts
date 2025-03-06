/**
 * Helper module for safely working with completion responses
 * and handling type compatibility issues
 */
import type {Provider_Name} from '$lib/provider_types.js';
import type {
	Provider_Data,
	Completion_Response,
	Ollama_Provider_Data,
	Claude_Provider_Data,
	Chatgpt_Provider_Data,
	Gemini_Provider_Data,
} from '$lib/message_types.js';
import {Datetime_Now, Uuid} from '$lib/zod_helpers.js';

/**
 * A unified Completion Response type that's compatible with both
 * Zod-inferred types and our manually defined types
 */
export interface Unified_Completion_Response extends Completion_Response {
	// Additional compatibility fields can be added here if needed
}

/**
 * Safe type assertion to cast a completion response to our unified type
 * Returns null for invalid responses to allow for null coalescing
 */
export const as_unified_response = (response: any): Unified_Completion_Response | null => {
	// Ensure we have a valid response
	if (!response) return null;

	// Create a proper Provider_Data object with required value
	if (response.data?.type && !response.data.value) {
		response.data.value = {};
	}

	return response as Unified_Completion_Response;
};

/**
 * Creates a standard completion response object
 */
export const create_completion_response = (
	request_id: string,
	provider_name: Provider_Name,
	model: string,
	provider_data: Provider_Data,
): Unified_Completion_Response => {
	return {
		created: Datetime_Now.parse(undefined),
		request_id: Uuid.parse(request_id),
		provider_name,
		model,
		data: provider_data,
	};
};

/**
 * Extract text content from a completion response based on provider type
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
