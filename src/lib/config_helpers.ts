// TODO expand similar to gitops/gro config

export type Zzz_Config_Creator = () => Zzz_Config;

export interface Zzz_Config {
	models: Models;
}

// TODO move where? make this data?
export type Model_Type = 'cheap' | 'smart';
export type Models = Record<Model_Type, {claude: string; gpt: string; gemini: string}>;
