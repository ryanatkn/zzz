import type Anthropic from '@anthropic-ai/sdk';
import type OpenAI from 'openai';
import type * as Google from '@google/generative-ai';
import type {ChatResponse} from 'ollama/browser';
import {z} from 'zod';

import {Provider_Name} from '$lib/provider.schema.js';
import {Uuid} from '$lib/uuid.js';
import {Datetime_Now} from '$lib/zod_helpers.js';

// Create proper Zod schema for Completion_Request
export const Completion_Request = z.object({
	created: Datetime_Now,
	request_id: Uuid,
	provider_name: Provider_Name,
	model: z.string(),
	prompt: z.string(),
});
export type Completion_Request = z.infer<typeof Completion_Request>;

// Enhanced schemas for vendor-specific data types - using z.any() with proper type refinements
export const Ollama_Completion_Data = z.object({
	type: z.literal('ollama'),
	// Use z.any() initially but refine to expected type structure
	value: z.any().refine(
		(_val): _val is ChatResponse => true, // Runtime check disabled, TypeScript enforced
		{message: 'Expected Ollama ChatResponse format'},
	),
});
export type Ollama_Completion_Data = z.infer<typeof Ollama_Completion_Data> & {
	value: ChatResponse;
};

export const Claude_Completion_Data = z.object({
	type: z.literal('claude'),
	value: z.any().refine((_val): _val is Anthropic.Messages.Message => true, {
		message: 'Expected Claude Message format',
	}),
});
export type Claude_Completion_Data = z.infer<typeof Claude_Completion_Data> & {
	value: Anthropic.Messages.Message;
};

export const Chatgpt_Completion_Data = z.object({
	type: z.literal('chatgpt'),
	value: z.any().refine((_val): _val is OpenAI.Chat.Completions.ChatCompletion => true, {
		message: 'Expected OpenAI ChatCompletion format',
	}),
});
export type Chatgpt_Completion_Data = z.infer<typeof Chatgpt_Completion_Data> & {
	value: OpenAI.Chat.Completions.ChatCompletion & {
		_request_id?: string | null;
	};
};

export const Gemini_Completion_Data = z.object({
	type: z.literal('gemini'),
	value: z
		.object({
			text: z.string(),
			candidates: z.array(z.any()).nullable(),
			function_calls: z.array(z.any()).nullable(),
			prompt_feedback: z.any().nullable(),
			usage_metadata: z.any().nullable(),
		})
		.refine(
			(
				_val,
			): _val is {
				text: string;
				candidates: Array<Google.GenerateContentCandidate> | null;
				function_calls: Array<Google.FunctionCall> | null;
				prompt_feedback: Google.PromptFeedback | null;
				usage_metadata: Google.UsageMetadata | null;
			} => true,
			{message: 'Expected Gemini result format'},
		),
});
export type Gemini_Completion_Data = z.infer<typeof Gemini_Completion_Data> & {
	value: {
		text: string;
		candidates: Array<Google.GenerateContentCandidate> | null;
		function_calls: Array<Google.FunctionCall> | null;
		prompt_feedback: Google.PromptFeedback | null;
		usage_metadata: Google.UsageMetadata | null;
	};
};

// Combine the response data schemas into a discriminated union
export const Completion_Response_Data = z.discriminatedUnion('type', [
	Ollama_Completion_Data,
	Claude_Completion_Data,
	Chatgpt_Completion_Data,
	Gemini_Completion_Data,
]);
export type Completion_Response_Data =
	| Ollama_Completion_Data
	| Claude_Completion_Data
	| Chatgpt_Completion_Data
	| Gemini_Completion_Data;

// Complete response schema
export const Completion_Response = z.object({
	created: Datetime_Now,
	request_id: Uuid,
	provider_name: Provider_Name,
	model: z.string(),
	data: Completion_Response_Data,
});
export type Completion_Response = z.infer<typeof Completion_Response>;

// Schema for the entire completion
export const Completion = z.object({
	completion_request: Completion_Request,
	completion_response: Completion_Response,
});
export type Completion = z.infer<typeof Completion>;

// Helper function for extracting text from completion responses
export const to_completion_response_text = (
	completion_response: Completion_Response,
): string | null | undefined => {
	switch (completion_response.data.type) {
		case 'ollama': {
			const data = completion_response.data.value;
			return data.message.content;
		}
		case 'claude': {
			const data = completion_response.data.value;
			return data.content
				.map((c) =>
					c.type === 'text'
						? c.text || ''
						: c.type === 'tool_use'
							? c.name || ''
							: c.type === 'thinking'
								? c.thinking || ''
								: '',
				)
				.join('\n\n');
		}
		case 'chatgpt': {
			const data = completion_response.data.value;
			return data.choices[0]?.message?.content || null;
		}
		case 'gemini': {
			const data = completion_response.data.value;
			return data.text || null;
		}
		default:
			return null;
	}
};
