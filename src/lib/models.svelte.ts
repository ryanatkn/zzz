import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Model, Model_Json} from '$lib/model.svelte.js';
import type {Ollama_Model_Info} from '$lib/ollama.js';
import {zzz_config} from '$lib/zzz_config.js';
import {cell_array} from '$lib/cell_helpers.js';

export const Models_Json = z
	.object({
		items: cell_array(
			z.array(Model_Json).default(() => []),
			'Model',
		),
	})
	.default(() => ({
		items: [],
	}));

export type Models_Json = z.infer<typeof Models_Json>;

export interface Models_Options extends Cell_Options<typeof Models_Json> {}

export class Models extends Cell<typeof Models_Json> {
	items: Array<Model> = $state([]);

	items_by_name: Map<string, Model> = $derived(new Map(this.items.map((m) => [m.name, m])));

	constructor(options: Models_Options) {
		super(Models_Json, options);
		this.init();
	}

	add(model_json: Model_Json): void {
		this.items.push(new Model({zzz: this.zzz, json: model_json}));
	}

	add_ollama_models(model_infos: Array<Ollama_Model_Info>): void {
		// First add the models that are installed
		const installed_ollama_models = model_infos.map((ollama_model_info) => {
			const model_default = zzz_config.models.find((m) => m.name === ollama_model_info.model.name);
			return new Model({
				zzz: this.zzz,
				json: model_default
					? {...model_default, ollama_model_info}
					: {
							name: ollama_model_info.model.name,
							provider_name: 'ollama',
							tags: ollama_model_info.model.details.families, // TODO maybe not this?
							ollama_model_info,
						},
			});
		});
		// Then add the models from the Zzz config that are not installed
		const uninstalled_ollama_models = zzz_config.models
			.filter(
				(m) =>
					m.provider_name === 'ollama' && !installed_ollama_models.some((m2) => m2.name === m.name),
			)
			.map((m) => new Model({zzz: this.zzz, json: m}));
		this.items = [...installed_ollama_models, ...uninstalled_ollama_models, ...this.items];
	}

	find_by_name(name: string): Model | undefined {
		return this.items_by_name.get(name);
	}

	// TODO maybe cache this in a derived?
	filter_by_names(names: Array<string>): Array<Model> | undefined {
		let found: Array<Model> | undefined;
		for (const name of names) {
			const model = this.items_by_name.get(name);
			if (model) {
				(found ??= []).push(model);
			}
		}
		return found;
	}

	find_by_tag(tag: string): Array<Model> {
		return this.items.filter((m) => m.tags.includes(tag));
	}

	remove_by_name(name: string): void {
		const index = this.items.findIndex((m) => m.name === name);
		if (index !== -1) {
			this.items.splice(index, 1);
		}
	}

	clear(): void {
		this.items.length = 0;
	}
}
