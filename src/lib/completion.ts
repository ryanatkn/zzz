import type Anthropic from '@anthropic-ai/sdk';
import type OpenAI from 'openai';
import type * as Google from '@google/generative-ai';
import type {ChatResponse} from 'ollama';

import type {Provider_Name} from '$lib/provider.svelte.js';
import type {Id} from '$lib/id.js';

export interface Completion_Request {
	created: string;
	request_id: Id;
	provider_name: Provider_Name;
	model: string;
	// TODO BLOCK `prompt` should be a `Prompt` type that captures the entire input to each API
	prompt: string;
}

export interface Completion_Response {
	created: string;
	request_id: Id;
	provider_name: Provider_Name;
	model: string;
	data:
		| {type: 'ollama'; value: ChatResponse}
		| {type: 'claude'; value: Anthropic.Messages.Message}
		| {
				type: 'chatgpt';
				value: OpenAI.Chat.Completions.ChatCompletion & {
					_request_id?: string | null;
				};
		  }
		| {
				type: 'gemini';
				value: {
					text: string;
					candidates: Array<Google.GenerateContentCandidate> | null;
					function_calls: Array<Google.FunctionCall> | null;
					prompt_feedback: Google.PromptFeedback | null;
					usage_metadata: Google.UsageMetadata | null;
				};
		  };
}

export interface Completion {
	completion_request: Completion_Request;
	completion_response: Completion_Response;
}
