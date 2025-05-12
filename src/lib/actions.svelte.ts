import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Action, Action_Schema} from '$lib/action.svelte.js';
import {Action_Json} from '$lib/action_types.js';
import {create_action_json} from '$lib/action_helpers.js';
import {Action_Method} from '$lib/action_metatypes.js';
import type {
	Action_Message_From_Client,
	Action_Message_From_Server,
} from '$lib/action_collections.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_multi_index} from '$lib/indexed_collection_helpers.js';

// TODO BLOCK so is this like our "dispatch context"? for each action,
// we may have one or more messages,
// created locally and sent for some kinds or processed locally for others, or received

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
	// TODO BLOCK maybe this class's data structure needs to change
	// so a single action can have multiple messages e.g. for those with kind request_response
	onsend: (action: Action_Message_From_Client) => void;
	onreceive: (action: Action_Message_From_Server) => void;
	history_limit?: number;
}

export class Actions extends Cell<typeof Actions_Json> {
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

	// These customize the class's behavior.
	// By default it just tracks actions in a collection when sent or received.
	onsend: (action: Action_Message_From_Client) => void;
	onreceive: (action: Action_Message_From_Server) => void;

	// TODO @many refactor this into the Indexed_Collection -- if this state remains we can have a setter that forwards the value
	history_limit: number = $state(HISTORY_LIMIT_DEFAULT);

	readonly pings: Array<Action> = $derived(this.items.where('by_method', 'ping'));
	readonly pongs: Array<Action> = $derived(this.items.where('by_method', 'pong'));
	readonly prompts: Array<Action> = $derived(this.items.where('by_method', 'submit_completion'));
	readonly completions: Array<Action> = $derived(
		this.items.where('by_method', 'completion_response'),
	);
	readonly diskfile_updates: Array<Action> = $derived(
		this.items.where('by_method', 'update_diskfile'),
	);
	readonly diskfile_deletes: Array<Action> = $derived(
		this.items.where('by_method', 'delete_diskfile'),
	);
	readonly filer_changes: Array<Action> = $derived(this.items.where('by_method', 'filer_change'));

	constructor(options: Actions_Options) {
		super(Actions_Json, options);

		this.onsend = options.onsend;
		this.onreceive = options.onreceive;

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
	 * Send an action using the registered handler with proper typing.
	 */
	send(message: Action_Message_From_Client): void {
		const action_json = create_action_json(message);
		if (!action_json) throw new Error(`Invalid action: ${message.method}`);
		this.add(action_json); // TODO BLOCK maybe the only concern here is history? in which case zzz can do this?

		this.onsend(message);
	}

	/**
	 * Handle a received action with proper typing.
	 */
	receive(message: Action_Message_From_Server): void {
		const action_json = create_action_json(message);
		if (!action_json) throw new Error(`Invalid action: ${message.method}`);
		this.add(action_json); // TODO BLOCK maybe the only concern here is history? in which case zzz can do this?

		this.onreceive(message);
	}

	/**
	 * Add an action to the collection.
	 */
	add(action_json: Action_Json): Action {
		const action = new Action({zzz: this.zzz, json: action_json});
		this.items.add(action);

		// Trim collection if it exceeds history limit
		this.#trim_to_history_limit();

		return action;
	}

	/**
	 * Get the latest N actions of a specific method.
	 *
	 * @param method The action method to filter by
	 * @param limit Maximum number of actions to return (defaults to history_limit)
	 * @returns Array of actions matching the type
	 */
	get_latest_by_method(method: Action_Method, limit: number = this.history_limit): Array<Action> {
		return this.items.latest('by_method', method, limit);
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
