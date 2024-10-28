import type Anthropic from '@anthropic-ai/sdk';
import type OpenAI from 'openai';
import type * as Google from '@google/generative-ai';

import type {Agent_Name} from '$lib/agent.svelte.js';
import type {Id} from '$lib/id.js';

export interface Completion_Request {
	request_id: Id;
	agent_name: Agent_Name;
	model: string;
	// TODO BLOCK `prompt` should be a `Prompt` type
	prompt: string;
}

export interface Completion_Response {
	request_id: Id;
	agent_name: Agent_Name;
	model: string;
	data:
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
					candidates: Google.GenerateContentCandidate[] | null;
					function_calls: Google.FunctionCall[] | null;
					prompt_feedback: Google.PromptFeedback | null;
					usage_metadata: Google.UsageMetadata | null;
				};
		  };
}

export interface Completion {
	completion_request: Completion_Request;
	completion_response: Completion_Response;
}
