import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Bit, Bit_Json, Bit_Schema, type Bit_Json_Input, type Bit_Type} from '$lib/bit.svelte.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_single_index} from '$lib/indexed_collection_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';
import {get_unique_name} from '$lib/helpers.js';

export const Bits_Json = z
	.object({
		items: cell_array(
			z.array(Bit_Json).default(() => []),
			'Bit',
		),
	})
	.default(() => ({
		items: [],
	}));
export type Bits_Json = z.infer<typeof Bits_Json>;
export type Bits_Json_Input = z.input<typeof Bits_Json>;

export interface Bits_Options extends Cell_Options<typeof Bits_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Bits extends Cell<typeof Bits_Json> {
	// Initialize items with proper typing and unified indexes
	readonly items: Indexed_Collection<Bit_Type> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'by_name',
				extractor: (bit) => bit.name,
				query_schema: z.string(),
				result_schema: Bit_Schema,
			}),
			create_single_index({
				key: 'by_diskfile_path',
				extractor: (bit) => (bit.type === 'diskfile' ? bit.path : undefined),
				query_schema: z.string(),
				result_schema: Bit_Schema,
			}),
			// TODO BLOCK dynamic index with the rendered content? needs to be lazy, ideally just using $derived
		],
	});

	constructor(options: Bits_Options) {
		super(Bits_Json, options);

		this.decoders = {
			// TODO @many maybe infer or create a helper for this, duplicated many places
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

	/**
	 * Add a bit to the collection.
	 */
	add(json: Bit_Json_Input): Bit_Type {
		if (!json.name) {
			json = {...json, name: this.generate_unique_name('new bit')};
		}
		const bit = Bit.create(this.zzz, json);
		this.items.add(bit);
		return bit;
	}

	/**
	 * Generate a unique name for a bit.
	 */
	generate_unique_name(base_name: string = 'new bit'): string {
		return get_unique_name(base_name, this.items.single_index('by_name'));
	}

	/**
	 * Remove a bit by id.
	 */
	remove(id: Uuid): boolean {
		return this.items.remove(id);
	}

	/**
	 * Find a bit that references a specific file path.
	 */
	find_bit_by_diskfile_path(path: string): Bit_Type | undefined {
		return this.items.single_index('by_diskfile_path').get(path);
	}
}
