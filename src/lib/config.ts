import type {Zzz_Config_Creator} from '$lib/config_helpers.js';
import type {Agent_Json} from '$lib/agent.svelte.js';
import type {Model_Json} from '$lib/model.svelte.js';

// TODO refactor - zzz.config.ts

export const default_agents: Array<Agent_Json> = [
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

export const default_models: Array<Model_Json> = [
	{name: 'claude-3-5-haiku-20241022', agent_name: 'claude', tags: ['cheap']},
	{name: 'claude-3-5-sonnet-20241022', agent_name: 'claude', tags: ['smart']},
	{name: 'gpt-4o-mini', agent_name: 'chatgpt', tags: ['cheap']},
	{name: 'gpt-4o', agent_name: 'chatgpt', tags: ['smart']},
	{name: 'chatgpt-4o-latest', agent_name: 'chatgpt', tags: ['evaluation']},
	{name: 'o1-preview', agent_name: 'chatgpt', tags: ['reasoning']},
	{name: 'o1-mini', agent_name: 'chatgpt', tags: ['reasoning']},
	{name: 'gemini-1.5-flash', agent_name: 'gemini', tags: ['cheap']},
	{name: 'gemini-1.5-pro', agent_name: 'gemini', tags: ['smart']},
];

export const SYSTEM_MESSAGE_DEFAULT =
	'You are a helpful and brilliant collaborator. Respond with a short creative message, one sentence in length, that continues from where the user left off, playing along for fun.';

// TODO currently this is imported directly by client and server, but we probably only want to forward a serialized subset to the client
const config: Zzz_Config_Creator = () => {
	return {
		agents: default_agents,
		models: default_models,
		system_message: SYSTEM_MESSAGE_DEFAULT,
	};
};

export default config;
