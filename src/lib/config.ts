import type {z} from 'zod';

import type {Zzz_Config_Creator} from '$lib/config_helpers.js';
import type {Provider_Json} from '$lib/provider.svelte.js';
import type {Model_Json} from '$lib/model.svelte.js';
import {merge_ollama_models, ollama_list_with_metadata} from '$lib/ollama.js';

// TODO BLOCK configure dirs - from env vars?

// TODO BLOCK instead of hardcoding Ollama models, pull from `http://127.0.0.1:11434/api/tags`

// TODO refactor - zzz.config.ts

// TODO other providers, or some generic one? (vercel, mistral, ...)

// TODO add WebLLM ? https://github.com/mlc-ai/web-llm - others?

export const providers_default: Array<z.input<typeof Provider_Json>> = [
	{
		name: 'ollama',
		icon: '',
		title: 'Ollama',
		url: 'https://ollama.com/',
	},
	{
		name: 'claude',
		icon: '',
		title: 'Claude',
		url: 'https://docs.anthropic.com/en/home',
	},
	{
		name: 'chatgpt',
		icon: '',
		title: 'ChatGPT',
		url: 'https://platform.openai.com/docs/overview',
	},
	{
		name: 'gemini',
		icon: '',
		title: 'Gemini',
		url: 'https://ai.google.dev/gemini-api/docs/',
	},
];

// TODO BLOCK show these on /chats if present here but not in Ollama data -- just have the buttons be disabled
// TODO BLOCK use these defaults to extend the ones added by ollama, `map_to_zzz_model`
export const models_default: Array<z.input<typeof Model_Json>> = [
	// TODO import/map these directly when possible
	{
		name: 'llama3.2:3b',
		provider_name: 'ollama',
		tags: ['llama', 'llama3'],
		architecture: 'llama',
		parameter_count: 3.21,
		context_window: 131_072,
		output_token_limit: 8_192,
		embedding_length: 3_072,
		filesize: 2.0,
		training_cutoff: 'December 2023',
	},
	{
		name: 'llama3.2:1b',
		provider_name: 'ollama',
		tags: ['llama', 'llama3', 'small'],
		architecture: 'llama',
		parameter_count: 1.24,
		context_window: 131_072,
		output_token_limit: 8_192,
		embedding_length: 2_048,
		filesize: 1.3,
		training_cutoff: 'December 2023',
	},
	{
		name: 'gemma:2b',
		provider_name: 'ollama',
		tags: ['gemma', 'small'],
		architecture: 'llama',
		parameter_count: 2.51,
		context_window: 8_192,
		output_token_limit: 16_384,
		embedding_length: 2_048,
		filesize: 1.7,
	},
	{
		name: 'qwen2.5:1.5b',
		provider_name: 'ollama',
		tags: ['qwen2', 'small'],
		architecture: 'qwen2',
		parameter_count: 1.54,
		context_window: 32_768,
		output_token_limit: 8_960,
		embedding_length: 1_536,
		filesize: 0.986,
	},
	{
		name: 'qwen2.5:0.5b',
		provider_name: 'ollama',
		tags: ['qwen2', 'small'],
		architecture: 'qwen2',
		parameter_count: 0.494,
		context_window: 32_768,
		output_token_limit: 4_864,
		embedding_length: 896,
		filesize: 0.398,
	},
	{
		name: 'deepseek-r1:7b',
		provider_name: 'ollama',
		tags: ['deepseek', 'reasoning'],
		architecture: 'qwen2',
		parameter_count: 7.62,
		context_window: 131_072,
		output_token_limit: 18_944,
		embedding_length: 3_584,
		filesize: 4.7,
	},
	{
		name: 'deepseek-r1:8b',
		provider_name: 'ollama',
		tags: ['deepseek', 'reasoning'],
		architecture: 'llama',
		parameter_count: 8.03,
		context_window: 131_072,
		embedding_length: 4_096,
		output_token_limit: 14_336,
		filesize: 4.9,
	},
	{
		name: 'deepseek-r1:1.5b',
		provider_name: 'ollama',
		tags: ['deepseek', 'reasoning', 'small'],
		architecture: 'qwen2',
		parameter_count: 1.78,
		context_window: 131_072,
		output_token_limit: 8_960,
		embedding_length: 1536,
		filesize: 1.1,
	},
	{
		name: 'claude-3-5-haiku-20241022',
		provider_name: 'claude',
		tags: ['cheap'],
		context_window: 200_000,
		output_token_limit: 8_192,
		cost_input: 3,
		cost_output: 15,
		training_cutoff: 'April 2024',
	},
	{
		name: 'claude-3-7-sonnet-20250219',
		provider_name: 'claude',
		tags: ['smart'],
		context_window: 200_000,
		output_token_limit: 128_192,
		cost_input: 0.8,
		cost_output: 4,
		training_cutoff: 'October 2024',
	},
	{
		name: 'claude-3-5-sonnet-20241022',
		provider_name: 'claude',
		tags: ['smart'],
		context_window: 200_000,
		output_token_limit: 8_192,
		cost_input: 0.8,
		cost_output: 4,
		training_cutoff: 'July 2024',
	},
	{
		name: 'gpt-4o-mini',
		provider_name: 'chatgpt',
		tags: ['cheap'],
		context_window: 128_000,
		output_token_limit: 16_384,
		cost_input: 0.15,
		cost_output: 0.6,
	},
	{
		name: 'gpt-4o',
		provider_name: 'chatgpt',
		tags: ['smart'],
		context_window: 128_000,
		output_token_limit: 16_384,
		cost_input: 2.5,
		cost_output: 10,
	},
	{
		name: 'chatgpt-4o-latest',
		provider_name: 'chatgpt',
		tags: ['smart'],
		context_window: 128_000,
		output_token_limit: 16_384,
		cost_input: 2.5,
		cost_output: 10,
	},
	// no access :[
	// {
	// 	name: 'o1',
	// 	provider_name: 'chatgpt',
	// 	tags: ['reasoning', 'smart'],
	// 	context_window: 200_000,
	// 	output_token_limit: 100_000,
	// 	cost_input: 15,
	// 	cost_output: 60,
	// },
	{
		name: 'o1-mini',
		provider_name: 'chatgpt',
		tags: ['reasoning'],
		context_window: 128_000,
		output_token_limit: 65_536,
		cost_input: 1.1,
		cost_output: 4.4,
	},
	// no access :[
	// {
	// 	name: 'o3-mini',
	// 	provider_name: 'chatgpt',
	// 	tags: ['reasoning', 'cheap'],
	// context_window: 200_000,
	// output_token_limit: 100_000,
	// 	cost_input: 1.1,
	// 	cost_output: 4.4,
	// },
	{
		name: 'gemini-2.0-flash-lite-preview-02-05',
		provider_name: 'gemini',
		tags: ['cheaper'],
		context_window: 1_048_576,
		output_token_limit: 8_192,
		cost_input: 0.075,
		cost_output: 0.3,
		training_cutoff: 'August 2024',
	},
	{
		name: 'gemini-2.0-flash',
		provider_name: 'gemini',
		tags: ['cheap'],
		context_window: 1_048_576,
		output_token_limit: 8_192,
		cost_input: 0.1,
		cost_output: 0.4,
		training_cutoff: 'August 2024',
	},
	{
		name: 'gemini-2.0-pro-exp-02-05',
		provider_name: 'gemini',
		tags: ['smart'],
		cost_input: 0.15,
		cost_output: 0.6,
	}, // TODO input is $0.075, prompts <= 128k tokens, $0.15, prompts > 128k tokens -- output is $0.30, prompts <= 128k tokens, $0.60, prompts > 128k tokens
	{
		name: 'gemini-2.0-flash-thinking-exp-01-21',
		provider_name: 'gemini',
		tags: ['cheap', 'reasoning'],
	},
	{
		name: 'gemini-1.5-pro',
		provider_name: 'gemini',
		tags: [],
		context_window: 2_000_000,
		cost_input: 2.5, // $1.25, prompts <= 128k tokens, $2.50, prompts > 128k tokens
		cost_output: 10, // $5.00, prompts <= 128k tokens, $10.00, prompts > 128k tokens
	},
];

export const SYSTEM_MESSAGE_DEFAULT =
	'You are a helpful assistant that responds with either a single, concise sentence, or a short structured response, as requested.';
// 'You are a helpful and brilliant collaborator. Respond with a short creative message, one sentence in length, that continues from where the user left off, playing along for fun.';

// TODO currently this is imported directly by client and server, but we probably only want to forward a serialized subset to the client
const config: Zzz_Config_Creator = async () => {
	const models_info = await ollama_list_with_metadata(); // TODO BLOCK cant do this here, maybe gen? where's the final source of truth? querying at runtime and caching in our db?

	const models = models_info
		? merge_ollama_models(models_default, models_info.model_infos)
		: models_default;

	return {
		providers: providers_default,
		models,
		system_message: SYSTEM_MESSAGE_DEFAULT,
		bots: {
			namerbot: 'llama3.2:1b',
		},
	};
};

export default config; // TODO I guess this acts like a seed file? `zzz.config.ts`? could we create a config helper with gro? (see the equivalent code in fuz_gitops)

/*
a = await fetch('http://127.0.0.1:11434/api/tags', {
  method: 'GET',
  mode: 'cors',
  headers: {
    'Content-Type': 'application/json'
  }
});
b = await a.json()
{
	models: [
		{
			name: 'gemma:2b',
			model: 'gemma:2b',
			modified_at: '2025-02-20T13:54:35.520976809-07:00',
			size: 1678456656,
			digest: 'b50d6c999e592ae4f79acae23b4feaefbdfceaa7cd366df2610e3072c052a160',
			details: {
				parent_model: '',
				format: 'gguf',
				family: 'gemma',
				families: ['gemma'],
				parameter_size: '3B',
				quantization_level: 'Q4_0',
			},
		},
		{
			name: 'qwen2.5:1.5b',
			model: 'qwen2.5:1.5b',
			modified_at: '2025-02-20T02:32:41.796099687-07:00',
			size: 986061892,
			digest: '65ec06548149b04c096a120e4a6da9d4017ea809c91734ea5631e89f96ddc57b',
			details: {
				parent_model: '',
				format: 'gguf',
				family: 'qwen2',
				families: ['qwen2'],
				parameter_size: '1.5B',
				quantization_level: 'Q4_K_M',
			},
		},
		{
			name: 'deepseek-r1:latest',
			model: 'deepseek-r1:latest',
			modified_at: '2025-02-19T08:11:57.96483293-07:00',
			size: 4683075271,
			digest: '0a8c266910232fd3291e71e5ba1e058cc5af9d411192cf88b6d30e92b6e73163',
			details: {
				parent_model: '',
				format: 'gguf',
				family: 'qwen2',
				families: ['qwen2'],
				parameter_size: '7.6B',
				quantization_level: 'Q4_K_M',
			},
		},
		{
			name: 'llama3.2:latest',
			model: 'llama3.2:latest',
			modified_at: '2025-02-18T10:29:34.93552234-07:00',
			size: 2019393189,
			digest: 'a80c4f17acd55265feec403c7aef86be0c25983ab279d83f3bcd3abbcb5b8b72',
			details: {
				parent_model: '',
				format: 'gguf',
				family: 'llama',
				families: ['llama'],
				parameter_size: '3.2B',
				quantization_level: 'Q4_K_M',
			},
		},
		{
			name: 'deepseek-r1:7b',
			model: 'deepseek-r1:7b',
			modified_at: '2025-02-17T20:33:10.862700855-07:00',
			size: 4683075271,
			digest: '0a8c266910232fd3291e71e5ba1e058cc5af9d411192cf88b6d30e92b6e73163',
			details: {
				parent_model: '',
				format: 'gguf',
				family: 'qwen2',
				families: ['qwen2'],
				parameter_size: '7.6B',
				quantization_level: 'Q4_K_M',
			},
		},
		{
			name: 'deepseek-r1:8b',
			model: 'deepseek-r1:8b',
			modified_at: '2025-02-17T15:08:15.155470114-07:00',
			size: 4920738407,
			digest: '28f8fd6cdc677661426adab9338ce3c013d7e69a5bea9e704b364171a5d61a10',
			details: {
				parent_model: '',
				format: 'gguf',
				family: 'llama',
				families: ['llama'],
				parameter_size: '8.0B',
				quantization_level: 'Q4_K_M',
			},
		},
		{
			name: 'deepseek-r1:1.5b',
			model: 'deepseek-r1:1.5b',
			modified_at: '2025-02-17T14:59:19.247070378-07:00',
			size: 1117322599,
			digest: 'a42b25d8c10a841bd24724309898ae851466696a7d7f3a0a408b895538ccbc96',
			details: {
				parent_model: '',
				format: 'gguf',
				family: 'qwen2',
				families: ['qwen2'],
				parameter_size: '1.8B',
				quantization_level: 'Q4_K_M',
			},
		},
		{
			name: 'llama3.2:1b',
			model: 'llama3.2:1b',
			modified_at: '2025-02-17T14:58:01.966973234-07:00',
			size: 1321098329,
			digest: 'baf6a787fdffd633537aa2eb51cfd54cb93ff08e28040095462bb63daf552878',
			details: {
				parent_model: '',
				format: 'gguf',
				family: 'llama',
				families: ['llama'],
				parameter_size: '1.2B',
				quantization_level: 'Q8_0',
			},
		},
	],
};
*/
