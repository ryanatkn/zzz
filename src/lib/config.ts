import type {Models, Zzz_Config_Creator} from '$lib/config_helpers.js';
import type {Agent_Json} from './agent.svelte.js';

// TODO refactor

export const default_models: Models = {
	cheap: {
		claude: 'claude-3-haiku-20240307',
		gpt: 'gpt-4o-mini',
		gemini: 'gemini-1.5-flash',
	},
	smart: {
		claude: 'claude-3-5-sonnet-20240620',
		gpt: 'gpt-4o',
		gemini: 'gemini-1.5-pro',
	},
} as const;

export const default_agents: Agent_Json[] = [
	{
		name: 'claude',
		icon: '',
		title: 'Claude',
		model: '',
		url: 'https://docs.anthropic.com/en/home',
	},
	{
		name: 'gpt',
		icon: '',
		title: 'ChatGPT',
		model: '',
		url: 'https://platform.openai.com/docs/overview',
	},
	{
		name: 'gemini',
		icon: '',
		title: 'Gemini',
		model: '',
		url: 'https://ai.google.dev/gemini-api/docs/',
	},
];

const config: Zzz_Config_Creator = () => {
	return {
		models: default_models,
		agents: default_agents,
	};
};

export default config;
