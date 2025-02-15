// TODO expand similar to gitops/gro config

import type {Agent_Json} from '$lib/agent.svelte.js';
import type {Model_Json} from '$lib/model.svelte.js';

export type Zzz_Config_Creator = () => Zzz_Config;

/**
 * @json
 */
export interface Zzz_Config {
	agents: Array<Agent_Json>;
	models: Array<Model_Json>;
	system_message: string | undefined;
}
