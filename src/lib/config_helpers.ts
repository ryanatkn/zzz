import type {Provider_Json_Input} from '$lib/provider.svelte.js';
import type {Model_Json_Input, Model_Name} from '$lib/model.svelte.js';

// TODO expand similar to gitops/gro config

// TODO is currently synchronous because it's imported on the client, could be made async if the client uses a different sourcing strategy
export type Zzz_Config_Creator = () => Zzz_Config;

/**
 * @json
 */
export interface Zzz_Config {
	providers: Array<Provider_Json_Input>;
	models: Array<Model_Json_Input>;
	system_message: string;
	output_token_max: number;
	temperature: number;
	seed: number | undefined;
	top_k: number | undefined;
	top_p: number | undefined;
	frequency_penalty: number | undefined;
	presence_penalty: number | undefined;
	stop_sequences: Array<string> | undefined;
	// TODO name?
	bots: {
		/**
		 * Names things.
		 */
		namerbot: Model_Name;
	};
}
