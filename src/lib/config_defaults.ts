import type {z} from 'zod';

import type {Provider_Json} from '$lib/provider.svelte.js';
import type {Model_Json} from '$lib/model.svelte.js';

// Configuration defaults
export const SYSTEM_MESSAGE_DEFAULT = 'You are a helpful assistant that responds succintly.'; // TODO without the succintly part? I dont think splitting it for DEV makes sense
export const OUTPUT_TOKEN_MAX_DEFAULT = 1000;
export const TEMPERATURE_DEFAULT = 0;
export const SEED_DEFAULT: number | undefined = undefined;
export const TOP_K_DEFAULT: number | undefined = undefined;
export const TOP_P_DEFAULT: number | undefined = undefined;
export const FREQUENCY_PENALTY_DEFAULT: number | undefined = undefined;
export const PRESENCE_PENALTY_DEFAULT: number | undefined = undefined;
export const STOP_SEQUENCES_DEFAULT: Array<string> | undefined = undefined;

// TODO needs work, hardcoding a bunch of stuff for now

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
