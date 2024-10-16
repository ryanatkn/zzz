import type {Models, Zzz_Config_Creator} from '$lib/config_helpers.js';

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

export const config: Zzz_Config_Creator = () => {
	return {
		models: default_models,
	};
};
