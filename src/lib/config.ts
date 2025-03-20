import type {Zzz_Config_Creator} from '$lib/config_helpers.js';
import {
	models_default,
	providers_default,
	SYSTEM_MESSAGE_DEFAULT,
	OUTPUT_TOKEN_MAX_DEFAULT,
	TEMPERATURE_DEFAULT,
	SEED_DEFAULT,
	TOP_K_DEFAULT,
	TOP_P_DEFAULT,
	FREQUENCY_PENALTY_DEFAULT,
	PRESENCE_PENALTY_DEFAULT,
	STOP_SEQUENCES_DEFAULT,
	BOTS_DEFAULT,
} from '$lib/config_defaults.js';

// TODO BLOCK instead of hardcoding Ollama models, pull from `http://127.0.0.1:11434/api/tags`

// TODO refactor - zzz.config.ts

// TODO currently this is imported directly by client and server, but we probably only want to forward a serialized subset to the client
const config: Zzz_Config_Creator = () => {
	return {
		providers: providers_default,
		models: models_default,
		system_message: SYSTEM_MESSAGE_DEFAULT,
		output_token_max: OUTPUT_TOKEN_MAX_DEFAULT,
		temperature: TEMPERATURE_DEFAULT,
		seed: SEED_DEFAULT,
		top_k: TOP_K_DEFAULT,
		top_p: TOP_P_DEFAULT,
		frequency_penalty: FREQUENCY_PENALTY_DEFAULT,
		presence_penalty: PRESENCE_PENALTY_DEFAULT,
		stop_sequences: STOP_SEQUENCES_DEFAULT,
		bots: BOTS_DEFAULT,
	};
};

export default config; // TODO I guess this acts like a seed file? `zzz.config.ts`? could we create a config helper with gro? (see the equivalent code in fuz_gitops)
