// TODO expand similar to gitops/gro config

import type {Agent_Json} from '$lib/agent.svelte.js';

export type Zzz_Config_Creator = () => Zzz_Config;

/**
 * @json
 */
export interface Zzz_Config {
	models: Models;
	agents: Agent_Json[];
}

// TODO move where? make this data?
export type Model_Type = 'cheap' | 'smart';
export type Models = Record<Model_Type, {claude: string; gpt: string; gemini: string}>;
