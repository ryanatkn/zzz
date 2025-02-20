// TODO expand similar to gitops/gro config

import type {Provider_Json} from '$lib/provider.svelte.js';
import type {Model_Json} from '$lib/model.svelte.js';

export type Zzz_Config_Creator = () => Zzz_Config | Promise<Zzz_Config>;

/**
 * @json
 */
export interface Zzz_Config {
	providers: Array<Provider_Json>;
	models: Array<Model_Json>;
	system_message: string | undefined;
}
