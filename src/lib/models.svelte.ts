import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Model, Model_Json} from '$lib/model.svelte.js';
import type {Ollama_Model_Info} from '$lib/ollama.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';

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

export interface Models_Options extends Cell_Options<typeof Models_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

// Define the key types for single and multi indexes
export type Model_Single_Index_Keys = 'name';
export type Model_Multi_Index_Keys = 'provider_name' | 'tag';

export class Models extends Cell<typeof Models_Json> {
	readonly items: Indexed_Collection<Model, Model_Single_Index_Keys, Model_Multi_Index_Keys> =
		new Indexed_Collection({
			single_indexes: [{key: 'name', extractor: (model: Model) => model.name}],
			multi_indexes: [
				{key: 'provider_name', extractor: (model: Model) => model.provider_name},
				{key: 'tag', extractor: (model: Model) => model.tags[0]}, // Index first tag for efficiency
			],
		});

	constructor(options: Models_Options) {
		super(Models_Json, options);

		// Add custom decoder for the items property to prevent overwriting our collection
		this.decoders = {
			items: (items) => {
				if (Array.isArray(items)) {
					this.items.clear();
					for (const item_json of items) {
						this.add(item_json);
					}
				}
				return HANDLED;
			},
		};

		this.init();
	}

	add(model_json: Model_Json): void {
		const model = new Model({zzz: this.zzz, json: model_json});
		this.items.add(model);
	}

	add_ollama_models(model_infos: Array<Ollama_Model_Info>): void {
		// First add the models that are installed
		const installed_ollama_models = model_infos.map((ollama_model_info) => {
			const model_default = this.items.by_optional('name', ollama_model_info.model.name);
			// TODO maybe clone would be cleaner?
			return new Model({
				zzz: this.zzz,
				json: model_default
					? {...model_default.json, ollama_model_info}
					: {
							name: ollama_model_info.model.name,
							provider_name: 'ollama',
							tags: ollama_model_info.model.details.families, // TODO maybe not this?
							ollama_model_info,
						},
			});
		});
		// Then add the models from config that are not installed
		const uninstalled_ollama_models = this.items
			.where('provider_name', 'ollama')
			.filter((m) => !installed_ollama_models.some((m2) => m2.name === m.name))
			.map((m) => new Model({zzz: this.zzz, json: m.json}));

		// Clear and add all models in the desired order
		this.items.clear();
		for (const model of [...installed_ollama_models, ...uninstalled_ollama_models]) {
			this.items.add(model);
		}
		// Add any remaining models that aren't Ollama models
		for (const model of this.items.all.filter((m) => m.provider_name !== 'ollama')) {
			this.items.add(model);
		}
	}

	find_by_name(name: string): Model | undefined {
		return this.items.by_optional('name', name);
	}

	filter_by_names(names: Array<string>): Array<Model> | undefined {
		const found = names.map((name) => this.items.by_optional('name', name)).filter((m) => !!m);
		return found.length ? found : undefined;
	}

	find_by_tag(tag: string): Array<Model> {
		return this.items.where('tag', tag);
	}

	remove_by_name(name: string): void {
		const model = this.items.by_optional('name', name);
		if (model) {
			this.items.remove(model.id);
		}
	}

	clear(): void {
		this.items.clear();
	}
}
