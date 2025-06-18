/**
 * Helper module for safely working with completion responses
 * and handling type compatibility issues.
 */
import {get_datetime_now} from '$lib/zod_helpers.js';
import type {Action_Outputs} from '$lib/action_collections.js';
import type {Provider_Name, Provider_Data} from '$lib/provider_types.js';
import type {Jsonrpc_Request_Id} from '$lib/jsonrpc.js';

/**
 * Extracts the text content from a completion response
 */
export const to_completion_response_text = (
	completion_response:
		| Action_Outputs['submit_completion']['completion_response']
		| null
		| undefined,
): string | null => {
	if (!completion_response) return null;

	const {data} = completion_response;

	switch (data.type) {
		case 'ollama':
			return data.value?.message?.content || null;
		case 'claude':
			return data.value?.content?.[0]?.text || null;
		case 'chatgpt':
			return data.value?.choices?.[0]?.message?.content || null;
		case 'gemini':
			return data.value.text || null;
		default:
			console.error('Unknown provider type', data);
			return null;
	}
};

/**
 * Creates a standardized completion response message from provider-specific responses
 */
export const to_completion_result = (
	request_id: Jsonrpc_Request_Id,
	provider_name: Provider_Name,
	model: string,
	api_response: unknown,
): Action_Outputs['submit_completion'] => {
	let provider_data: Provider_Data;

	// Convert provider-specific response format to our standard format
	switch (provider_name) {
		case 'ollama':
			provider_data = {
				type: 'ollama',
				value: api_response,
			};
			break;
		case 'claude':
			provider_data = {
				type: 'claude',
				value: api_response,
			};
			break;
		case 'chatgpt':
			provider_data = {
				type: 'chatgpt',
				value: api_response,
			};
			break;
		case 'gemini':
			provider_data = {
				type: 'gemini',
				value: {
					text: (api_response as any)?.response?.text() || '',
					candidates: (api_response as any)?.candidates || null,
					function_calls: (api_response as any)?.functionCalls || null,
					prompt_feedback: (api_response as any)?.promptFeedback || null,
					usage_metadata: (api_response as any)?.usageMetadata || null,
				},
			};
			break;
		default:
			throw new Error(`Unsupported provider: ${provider_name}`);
	}

	const created = get_datetime_now();

	return {
		completion_response: {
			created,
			request_id,
			provider_name,
			model,
			data: provider_data,
		},
	};
};
