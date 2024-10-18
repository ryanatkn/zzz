import type {Zzz_Config_Creator} from '$lib/config_helpers.js';
import type {Agent_Json} from './agent.svelte.js';

// TODO refactor

export const default_agents: Agent_Json[] = [
	{
		name: 'claude',
		icon: '',
		title: 'Claude',
		model: 'claude-3-haiku-20240307',
		models: {
			cheap: 'claude-3-haiku-20240307',
			smart: 'claude-3-5-sonnet-20240620',
		},
		url: 'https://docs.anthropic.com/en/home',
	},
	{
		name: 'gpt',
		icon: '',
		title: 'ChatGPT',
		model: 'gpt-4o-mini',
		models: {
			cheap: 'gpt-4o-mini',
			smart: 'gpt-4o',
		},
		url: 'https://platform.openai.com/docs/overview',
	},
	{
		name: 'gemini',
		icon: '',
		title: 'Gemini',
		model: 'gemini-1.5-flash',
		models: {
			cheap: 'gemini-1.5-flash',
			smart: 'gemini-1.5-pro',
		},
		url: 'https://ai.google.dev/gemini-api/docs/',
	},
];

export const SYSTEM_MESSAGE_DEFAULT =
	'You are a helpful assistant. Respond with a very short creative message, just a short sentence or two in length, that continues from where the user left off, playing along for fun.';

const config: Zzz_Config_Creator = () => {
	return {
		agents: default_agents,
		system_message: SYSTEM_MESSAGE_DEFAULT,
	};
};

export default config;
