import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Model, Model_Json, Model_Schema} from '$lib/model.svelte.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {
	create_single_index,
	create_multi_index,
	create_derived_index,
} from '$lib/indexed_collection_helpers.js';
import {merge_ollama_models, type Ollama_Model_Info} from '$lib/ollama.js';

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

export class Models extends Cell<typeof Models_Json> {
	readonly items: Indexed_Collection<Model> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'name',
				extractor: (model) => model.name,
				query_schema: z.string(),
				result_schema: Model_Schema,
			}),

			create_multi_index({
				key: 'provider_name',
				extractor: (model) => model.provider_name,
				query_schema: z.string(),
				result_schema: Model_Schema,
			}),

			create_multi_index({
				key: 'tag',
				extractor: (model) => model.tags,
				query_schema: z.string(),
				matches: (model) => model.tags.length > 0,
				result_schema: Model_Schema,
			}),

			create_derived_index({
				key: 'ordered_by_name',
				compute: (collection) => Array.from(collection.by_id.values()),
				sort: (a, b) => a.name.localeCompare(b.name),
				result_schema: z.array(Model_Schema),
			}),
		],
	});

	/** Get all models ordered alphabetically by name. */
	ordered_by_name: Array<Model> = $derived(this.items.derived_index('ordered_by_name'));

	constructor(options: Models_Options) {
		super(Models_Json, options);

		// Add custom decoder for the items property,
		// which also prevents it from automatically overwriting our collection
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

	add_many(models_json: Array<Model_Json>): void {
		this.items.clear();
		for (const model_json of models_json) {
			this.add(model_json);
		}
	}

	// TODO BLOCK use or delete
	merge(model_infos: Array<Ollama_Model_Info>): void {
		merge_ollama_models(Array.from(this.items.by_id.values()), model_infos); // TODO @many should `items.by_id.values()` be a derived even if often inefficient? still better than constructing it multiple times? or should this be an index?
	}

	find_by_name(name: string): Model | undefined {
		return this.items.by_optional('name', name);
	}

	filter_by_names(names: Array<string>): Array<Model> | undefined {
		let found: Array<Model> | undefined = undefined;

		for (const name of names) {
			const model = this.items.by_optional('name', name);
			if (!model) continue;
			(found ??= []).push(model);
		}

		return found;
	}

	filter_by_tag(tag: string): Array<Model> {
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
