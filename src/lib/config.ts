import type {Zzz_Config_Creator} from '$lib/config_helpers.js';
import type {Agent_Json} from '$lib/agent.svelte.js';
import type {Model_Json} from '$lib/model.svelte.js';

// TODO refactor

export const default_agents: Agent_Json[] = [
	{
		name: 'claude',
		icon: '',
		title: 'Claude',
		url: 'https://docs.anthropic.com/en/home',
	},
	{
		name: 'gpt',
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

export const default_models: Model_Json[] = [
	{name: 'claude-3-haiku-20240307', agent_name: 'claude', tags: ['cheap']},
	{name: 'claude-3-5-sonnet-20240620', agent_name: 'claude', tags: ['smart']},
	{name: 'gpt-4o-mini', agent_name: 'gpt', tags: ['cheap']},
	{name: 'gpt-4o', agent_name: 'gpt', tags: ['smart']},
	{name: 'o1-preview', agent_name: 'gpt', tags: ['reasoning']},
	{name: 'o1-mini', agent_name: 'gpt', tags: ['reasoning']},
	{name: 'gemini-1.5-flash', agent_name: 'gemini', tags: ['cheap']},
	{name: 'gemini-1.5-pro', agent_name: 'gemini', tags: ['smart']},
];

export const SYSTEM_MESSAGE_DEFAULT =
	'You are a helpful assistant. Respond with a very short creative message, just a short sentence or two in length, that continues from where the user left off, playing along for fun.';

const config: Zzz_Config_Creator = () => {
	return {
		agents: default_agents,
		models: default_models,
		system_message: SYSTEM_MESSAGE_DEFAULT,
	};
};

export default config;
