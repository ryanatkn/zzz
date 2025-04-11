import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Action, Action_Schema} from '$lib/action.svelte.js';
import {
	Action_Json,
	type Action_Client,
	type Action_Server,
	create_action_json,
	Action_Type,
} from '$lib/action_types.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_multi_index} from '$lib/indexed_collection_helpers.js';

export const HISTORY_LIMIT_DEFAULT = 512;
export const PONG_DISPLAY_LIMIT = 6;

export const Actions_Json = z
	.object({
		items: cell_array(
			z.array(Action_Json).default(() => []),
			'Action',
		),
	})
	.default(() => ({
		items: [],
	}));
export type Actions_Json = z.infer<typeof Actions_Json>;
export type Actions_Json_Input = z.input<typeof Actions_Json>;

export interface Actions_Options extends Cell_Options<typeof Actions_Json> {
	history_limit?: number;
}

export class Actions extends Cell<typeof Actions_Json> {
	readonly items: Indexed_Collection<Action> = new Indexed_Collection({
		indexes: [
			create_multi_index({
				key: 'by_type',
				extractor: (action) => action.type,
				query_schema: Action_Type,
				result_schema: Action_Schema,
			}),
		],
	});

	history_limit: number = $state(HISTORY_LIMIT_DEFAULT);

	// Derived collections using the indexed structure
	readonly pings: Array<Action> = $derived(this.items.where('by_type', 'ping'));
	readonly pongs: Array<Action> = $derived(this.items.where('by_type', 'pong'));
	readonly prompts: Array<Action> = $derived(this.items.where('by_type', 'send_prompt'));
	readonly completions: Array<Action> = $derived(
		this.items.where('by_type', 'completion_response'),
	);
	readonly diskfile_updates: Array<Action> = $derived(
		this.items.where('by_type', 'update_diskfile'),
	);
	readonly diskfile_deletes: Array<Action> = $derived(
		this.items.where('by_type', 'delete_diskfile'),
	);
	readonly filer_changes: Array<Action> = $derived(this.items.where('by_type', 'filer_change'));

	// Action handlers
	onsend?: (action: Action_Client) => void;
	onreceive?: (action: Action_Server) => void;

	constructor(options: Actions_Options) {
		super(Actions_Json, options);

		// Set history limit if provided
		if (options.history_limit !== undefined) {
			this.history_limit = options.history_limit;
		}

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
	 * Override to populate the indexed collection after parsing JSON.
	 */
	override set_json(value?: Actions_Json_Input): void {
		super.set_json(value);

		// Trim to history limit after loading
		this.#trim_to_history_limit(); // TODO should be unnecessary to override `set_json` for this
	}

	/**
	 * Send a action using the registered handler with proper typing.
	 */
	send(action: Action_Client): void {
		if (!this.onsend) {
			console.error('No send handler registered', action);
			return;
		}

		this.add(create_action_json(action, 'client'));
		this.onsend(action);
	}

	/**
	 * Handle a received action with proper typing.
	 */
	receive(action: Action_Server): void {
		if (!this.onreceive) {
			console.error('No receive handler registered');
			return;
		}

		this.add(create_action_json(action, 'server'));
		this.onreceive(action);
	}

	/**
	 * Add a action to the collection.
	 */
	add(action_json: Action_Json): Action {
		const action = new Action({zzz: this.zzz, json: action_json});
		this.items.add(action);

		// Trim collection if it exceeds history limit
		this.#trim_to_history_limit();

		return action;
	}

	/**
	 * Get the latest N actions of a specific type.
	 *
	 * @param type The action type to filter by
	 * @param limit Maximum number of actions to return (defaults to history_limit)
	 * @returns Array of actions matching the type
	 */
	get_latest_by_type(type: Action_Type, limit: number = this.history_limit): Array<Action> {
		return this.items.latest('by_type', type, limit);
	}

	/**
	 * Trims the collection to the maximum allowed size by removing oldest actions.
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
