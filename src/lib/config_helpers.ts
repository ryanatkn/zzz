// TODO expand similar to gitops/gro config

import type {Agent_Json, Agent_Name} from '$lib/agent.svelte.js';

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
export type Models = Record<Agent_Name, Record<Model_Type, string>>;
