import type {z} from 'zod';

import type {Provider_Json_Input} from '$lib/provider.svelte.js';
import type {Model_Json, Model_Name} from '$lib/model.svelte.js';
import type {Chat_Template} from '$lib/chat_template.js';
import {create_uuid} from '$lib/zod_helpers.js';

// TODO BLOCK rethink for Ollama
export const small_recommended_models: Array<Model_Name> = [
	'gemma3:1b',
	'qwen3:0.6b',
	'deepseek-r1:1.5b',
	'llama3.2:1b',
	'phi4-mini:3.8b',
	'smollm2:135m',
	'smollm2:360m',
	'smollm2:1.7b',
];

// TODO this is a temporary source of truth, use APIs instead
// TODO @many refactor with db

// Configuration defaults
// TODO without the succinctly part - I dont think splitting it for DEV makes sense, make a UI affordance instead
export const SYSTEM_MESSAGE_DEFAULT = 'You are a helpful assistant that responds succinctly.';
export const OUTPUT_TOKEN_MAX_DEFAULT = 1000;
export const TEMPERATURE_DEFAULT = 0;
export const SEED_DEFAULT: number | undefined = undefined;
export const TOP_K_DEFAULT: number | undefined = undefined;
export const TOP_P_DEFAULT: number | undefined = undefined;
export const FREQUENCY_PENALTY_DEFAULT: number | undefined = undefined;
export const PRESENCE_PENALTY_DEFAULT: number | undefined = undefined;
export const STOP_SEQUENCES_DEFAULT: Array<string> | undefined = undefined;
export const BOTS_DEFAULT = {
	namerbot: 'llama3.2:1b',
};

// TODO needs work, hardcoding a bunch of stuff for now

// TODO other providers, or some generic one? (vercel, mistral, ...)

// TODO add WebLLM ? https://github.com/mlc-ai/web-llm - others?

export const providers_default: Array<Provider_Json_Input> = [
	{
		name: 'ollama',
		icon: '',
		title: 'Ollama',
		url: 'https://github.com/ollama/ollama/tree/main/docs',
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

// TODO any data here beyond name/provider_name/tags (and probably some future ones) should be fetched from the provider API
// TODO @db refactor with db
export const models_default: Array<z.input<typeof Model_Json>> = [
	// TODO BLOCK remove but make sure these are all mapped
	// {
	// 	name: 'llama3.2:3b',
	// 	provider_name: 'ollama',
	// 	tags: ['llama', 'llama3'],
	// },
	// {
	// 	name: 'llama3.2:1b',
	// 	provider_name: 'ollama',
	// 	tags: ['llama', 'llama3', 'small'],
	// },
	// {
	// 	name: 'gemma3:1b',
	// 	provider_name: 'ollama',
	// 	tags: ['gemma', 'small'],
	// },
	// {
	// 	name: 'gemma3:4b',
	// 	provider_name: 'ollama',
	// 	tags: ['gemma', 'small'],
	// },
	// {
	// 	name: 'qwen2.5:1.5b',
	// 	provider_name: 'ollama',
	// 	tags: ['qwen2', 'small'],
	// },
	// {
	// 	name: 'qwen2.5:0.5b',
	// 	provider_name: 'ollama',
	// 	tags: ['qwen2', 'small'],
	// },
	// {
	// 	name: 'deepseek-r1:7b',
	// 	provider_name: 'ollama',
	// 	tags: ['deepseek', 'reasoning'],
	// },
	// {
	// 	name: 'deepseek-r1:8b',
	// 	provider_name: 'ollama',
	// 	tags: ['deepseek', 'reasoning'],
	// },
	// {
	// 	name: 'deepseek-r1:1.5b',
	// 	provider_name: 'ollama',
	// 	tags: ['deepseek', 'reasoning', 'small'],
	// },
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
];

/**
 * Default chat templates available in the application
 */
export const chat_template_defaults: Array<Chat_Template> = [
	{
		id: create_uuid(),
		name: 'small and local',
		model_names: ['llama3.2:1b', 'gemma3:1b', 'qwen2.5:0.5b'],
	},
	{
		id: create_uuid(),
		name: 'frontier',
		model_names: ['claude-3-7-sonnet-20250219', 'chatgpt-4o-latest', 'gemini-2.0-pro-exp-02-05'],
	},
	{
		id: create_uuid(),
		name: 'local comparison',
		model_names: [
			'llama3.2:1b',
			'llama3.2:3b',
			'gemma3:1b',
			'gemma3:4b',
			'qwen2.5:0.5b',
			'qwen2.5:1.5b',
		],
	},
];
