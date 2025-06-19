import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Action, Action_Json, Action_Schema, type Action_Json_Input} from '$lib/action.svelte.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_multi_index} from '$lib/indexed_collection_helpers.js';
import {Cell_Json} from '$lib/cell_types.js';

export const HISTORY_LIMIT_DEFAULT = 512;
export const PONG_DISPLAY_LIMIT = 6;

export const Actions_Json = Cell_Json.extend({
	items: cell_array(
		z.array(Action_Json).default(() => []),
		'Action',
	),
});
export type Actions_Json = z.infer<typeof Actions_Json>;
export type Actions_Json_Input = z.input<typeof Actions_Json>;

export interface Actions_Options extends Cell_Options<typeof Actions_Json> {
	history_limit?: number;
}

/** Stores the action history. */
export class Actions extends Cell<typeof Actions_Json> {
	// TODO maybe rename to `history`, or extract an `Action_History` or more generic class
	readonly items: Indexed_Collection<Action> = new Indexed_Collection({
		indexes: [
			create_multi_index({
				key: 'by_method',
				extractor: (action) => action.method,
				query_schema: Action_Method,
				result_schema: Action_Schema,
			}),
		],
	});

	// TODO @many refactor this into the Indexed_Collection -- if this state remains we can have a setter that forwards the value
	history_limit: number = $state(HISTORY_LIMIT_DEFAULT);

	// TODO think about these
	// readonly pings: Array<Action> = $derived(this.items.where('by_method', 'ping'));
	// get_latest_by_method(method: Action_Method, limit: number = this.history_limit): Array<Action> {
	// 	return this.items.latest('by_method', method, limit);
	// }

	constructor(options: Actions_Options) {
		super(Actions_Json, options);

		// Set history limit if provided
		if (options.history_limit !== undefined) {
			this.history_limit = options.history_limit;
		}

		this.decoders = {
			// TODO @many improve this API, maybe infer or create a helper, duplicated many places
			items: (items) => {
				if (Array.isArray(items)) {
					this.items.clear();
					for (const item_json of items) {
						this.add_from_json(item_json);
					}
				}
				return HANDLED;
			},
		};

		this.init();
	}

	/**
	 * Override to populate the indexed collection after parsing JSON.
	 */
	override set_json(value?: Actions_Json_Input): void {
		super.set_json(value);

		// Trim to history limit after loading
		this.#trim_to_history_limit(); // TODO should be unnecessary to override `set_json` for this
	}

	add(action: Action): void {
		this.items.add(action);

		// TODO refactor
		this.#trim_to_history_limit();
	}

	add_from_json(action_json: Action_Json_Input): Action {
		const action = new Action({app: this.app, json: action_json});
		this.add(action);
		return action;
	}

	// TODO @many refactor this into the Indexed_Collection -- need to test the new behavior
	/**
	 * Trims the collection to the maximum allowed size by removing oldest actions. (FIFO)
	 */
	#trim_to_history_limit(): void {
		// Calculate how many items to remove and use the optimized method
		const excess = this.items.size - this.history_limit;
		if (excess <= 0) return;
		const ids = [];
		for (const action of this.items.by_id.values()) {
			ids.push(action.id);
			if (ids.length === excess) break;
		}
		this.items.remove_many(ids);
	}
}
