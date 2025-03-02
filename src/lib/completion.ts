import type Anthropic from '@anthropic-ai/sdk';
import type OpenAI from 'openai';
import type * as Google from '@google/generative-ai';
import type {ChatResponse} from 'ollama/browser';
import {z} from 'zod';

import {Provider_Name} from '$lib/provider.schema.js';
import {Uuid} from '$lib/uuid.js';

export interface Completion {
	completion_request: Completion_Request;
	completion_response: Completion_Response;
}

export const Completion_Request = z.object({
	created: z
		.string()
		.datetime()
		.default(() => new Date().toISOString()),
	request_id: Uuid,
	provider_name: Provider_Name,
	model: z.string(),
	prompt: z.string(),
});
export type Completion_Request = z.infer<typeof Completion_Request>;

export interface Completion_Response {
	created: string;
	request_id: Uuid;
	provider_name: Provider_Name;
	model: string;
	data: Completion_Response_Data;
}

// Union type of all possible data structures
export type Completion_Response_Data =
	| Ollama_Completion_Data
	| Claude_Completion_Data
	| Chatgpt_Completion_Data
	| Gemini_Completion_Data;

// Define specific data types for each provider
export interface Ollama_Completion_Data {
	type: 'ollama';
	value: ChatResponse;
}

export interface Claude_Completion_Data {
	type: 'claude';
	value: Anthropic.Messages.Message;
}

export interface Chatgpt_Completion_Data {
	type: 'chatgpt';
	value: OpenAI.Chat.Completions.ChatCompletion & {
		_request_id?: string | null;
	};
}

export interface Gemini_Completion_Data {
	type: 'gemini';
	value: {
		text: string;
		candidates: Array<Google.GenerateContentCandidate> | null;
		function_calls: Array<Google.FunctionCall> | null;
		prompt_feedback: Google.PromptFeedback | null;
		usage_metadata: Google.UsageMetadata | null;
	};
}

// Placeholder schemas for use in Zod validation without inferring types
export const Completion_Response_Data_Schema = z.object({
	type: Provider_Name,
	value: z.any(),
});

export const Completion_Response_Schema = z.object({
	created: z
		.string()
		.datetime()
		.default(() => new Date().toISOString()),
	request_id: Uuid,
	provider_name: Provider_Name,
	model: z.string(),
	data: Completion_Response_Data_Schema,
});

export const Completion_Schema = z.object({
	completion_request: Completion_Request,
	completion_response: Completion_Response_Schema,
});

// Helper function remains the same
export const to_completion_response_text = (
	completion_response: Completion_Response,
): string | null | undefined => {
	if (!completion_response.data) return null;

	switch (completion_response.data.type) {
		case 'ollama':
			return completion_response.data.value.message.content;
		case 'claude':
			return completion_response.data.value.content
				.map((c) =>
					c.type === 'text'
						? c.text
						: c.type === 'tool_use'
							? c.name
							: c.type === 'thinking'
								? c.thinking
								: c.data,
				)
				.join('\n\n');
		case 'chatgpt':
			return completion_response.data.value.choices[0].message.content;
		case 'gemini':
			return completion_response.data.value.text;
		default:
			return null;
	}
};
