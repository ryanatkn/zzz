import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Part, Part_Json, type Part_Json_Input, type Part_Union} from '$lib/part.svelte.js';
import {HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_single_index} from '$lib/indexed_collection_helpers.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {get_unique_name} from '$lib/helpers.js';
import {Cell_Json} from '$lib/cell_types.js';

export const Parts_Json = Cell_Json.extend({
	items: z.array(Part_Json).default(() => []),
}).meta({cell_class_name: 'Parts'});
export type Parts_Json = z.infer<typeof Parts_Json>;
export type Parts_Json_Input = z.input<typeof Parts_Json>;

export interface Parts_Options extends Cell_Options<typeof Parts_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Parts extends Cell<typeof Parts_Json> {
	// Initialize items with proper typing and unified indexes
	readonly items: Indexed_Collection<Part_Union> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'by_name',
				extractor: (part) => part.name,
				query_schema: z.string(),
			}),
			create_single_index({
				key: 'by_diskfile_path',
				extractor: (part) => (part.type === 'diskfile' ? part.path : undefined),
				query_schema: z.string(),
			}),
			// TODO dynamic index with the rendered content? needs to be lazy, ideally just using $derived
		],
	});

	constructor(options: Parts_Options) {
		super(Parts_Json, options);

		this.decoders = {
			// TODO @many improve this API, maybe infer or create a helper, duplicated many places
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

	// TODO this json type is incorrect, it should have `json.type` as required
	/**
	 * Add a part to the collection.
	 */
	add(json: Part_Json_Input): Part_Union {
		const j = !json.name ? {...json, name: this.generate_unique_name('new part')} : json;
		const part = Part.create(this.app, j);
		this.items.add(part);
		return part;
	}

	/**
	 * Generate a unique name for a part.
	 */
	generate_unique_name(base_name: string = 'new part'): string {
		return get_unique_name(base_name, this.items.single_index('by_name'));
	}

	/**
	 * Remove a part by id.
	 */
	remove(id: Uuid): boolean {
		return this.items.remove(id);
	}

	/**
	 * Find a part that references a specific file path.
	 */
	find_part_by_diskfile_path(path: string): Part_Union | undefined {
		return this.items.single_index('by_diskfile_path').get(path);
	}
}
