import type {z} from 'zod';

import type {Provider_Json} from '$lib/provider.svelte.js';
import type {Model_Json, Model_Name} from '$lib/model.svelte.js';

// TODO expand similar to gitops/gro config

export type Zzz_Config_Creator = () => Zzz_Config | Promise<Zzz_Config>;

/**
 * @json
 */
export interface Zzz_Config {
	providers: Array<z.input<typeof Provider_Json>>;
	models: Array<z.input<typeof Model_Json>>;
	system_message: string | undefined;
	// TODO name?
	bots: {
		/**
		 * Names things.
		 */
		namerbot: Model_Name;
	};
}
