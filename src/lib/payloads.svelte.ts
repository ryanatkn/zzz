import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Payload, Payload_Schema} from '$lib/payload.svelte.js';
import {
	Payload_Json,
	type Payload_Client,
	type Payload_Server,
	create_payload_json,
	Payload_Type,
} from '$lib/payload_types.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_multi_index, create_derived_index} from '$lib/indexed_collection_helpers.js';

export const HISTORY_LIMIT_DEFAULT = 512;
export const PONG_DISPLAY_LIMIT = 6;

export const Payloads_Json = z
	.object({
		items: cell_array(
			z.array(Payload_Json).default(() => []),
			'Payload',
		),
	})
	.default(() => ({
		items: [],
	}));

export type Payloads_Json = z.infer<typeof Payloads_Json>;

export interface Payloads_Options extends Cell_Options<typeof Payloads_Json> {
	history_limit?: number;
}

// Define our index keys for type safety
export type Payload_Multi_Index_Keys = 'by_type' | 'by_ping_id';

export class Payloads extends Cell<typeof Payloads_Json> {
	// Configure indexed collection with unified indexing system
	readonly items: Indexed_Collection<Payload> = new Indexed_Collection({
		indexes: [
			// Type-based multi-index
			create_multi_index({
				key: 'by_type',
				extractor: (payload) => payload.type,
				query_schema: z.enum([
					'ping',
					'pong',
					'send_prompt',
					'completion_response',
					'update_diskfile',
					'delete_diskfile',
					'filer_change',
				]),
				result_schema: Payload_Schema,
			}),

			// Ping id index for pongs
			create_multi_index({
				key: 'by_ping_id',
				extractor: (payload) => {
					if (payload.type === 'pong' && payload.ping_id) {
						return payload.ping_id;
					}
					return undefined;
				},
				query_schema: z.string(),
				matches: (payload) => payload.type === 'pong' && !!payload.ping_id,
				result_schema: Payload_Schema,
			}),

			// Derived index for latest pongs - prioritize showing most recent
			create_derived_index({
				key: 'latest_pongs',
				compute: (collection) => {
					return collection
						.where('by_type', 'pong')
						.sort((a, b) => b.created.localeCompare(a.created))
						.slice(0, PONG_DISPLAY_LIMIT);
				},
				matches: (item) => item.type === 'pong',
				result_schema: Payload_Schema,
				onadd: (items, item) => {
					if (item.type !== 'pong') return items;

					// Insert at correct position based on created timestamp
					const index = items.findIndex((existing) => item.created > existing.created);

					if (index === -1) {
						items.push(item);
					} else {
						items.splice(index, 0, item);
					}

					// Keep only the newest items
					if (items.length > PONG_DISPLAY_LIMIT) {
						return items.slice(0, PONG_DISPLAY_LIMIT);
					}

					return items;
				},
				onremove: (items, item) => {
					const index = items.findIndex((i) => i.id === item.id);
					if (index !== -1) {
						items.splice(index, 1);
					}
					return items;
				},
			}),
		],
	});

	history_limit: number = $state(HISTORY_LIMIT_DEFAULT);

	// Derived collections using the indexed structure
	pings: Array<Payload> = $derived(this.items.where('by_type', 'ping'));
	pongs: Array<Payload> = $derived(this.items.where('by_type', 'pong'));
	prompts: Array<Payload> = $derived(this.items.where('by_type', 'send_prompt'));
	completions: Array<Payload> = $derived(this.items.where('by_type', 'completion_response'));
	diskfile_updates: Array<Payload> = $derived(this.items.where('by_type', 'update_diskfile'));
	diskfile_deletes: Array<Payload> = $derived(this.items.where('by_type', 'delete_diskfile'));
	filer_changes: Array<Payload> = $derived(this.items.where('by_type', 'filer_change'));

	// Payload handlers
	onsend?: (payload: Payload_Client) => void;
	onreceive?: (payload: Payload_Server) => void;

	constructor(options: Payloads_Options) {
		super(Payloads_Json, options);

		// Set history limit if provided
		if (options.history_limit !== undefined) {
			this.history_limit = options.history_limit;
		}

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

	/**
	 * Override to populate the indexed collection after parsing JSON.
	 */
	override set_json(value?: z.input<typeof Payloads_Json>): void {
		super.set_json(value);

		// Trim to history limit after loading
		this.#trim_to_history_limit(); // TODO should be unnecessary to override `set_json` for this
	}

	/**
	 * Send a payload using the registered handler with proper typing.
	 */
	send(payload: Payload_Client): void {
		if (!this.onsend) {
			console.error('No send handler registered', payload);
			return;
		}

		this.add(create_payload_json(payload, 'client'));
		this.onsend(payload);
	}

	/**
	 * Handle a received payload with proper typing.
	 */
	receive(payload: Payload_Server): void {
		if (!this.onreceive) {
			console.error('No receive handler registered');
			return;
		}

		this.add(create_payload_json(payload, 'server'));
		this.onreceive(payload);
	}

	/**
	 * Add a payload to the collection.
	 */
	add(payload_json: Payload_Json): Payload {
		const payload = new Payload({zzz: this.zzz, json: payload_json});
		this.items.add(payload);

		// Trim collection if it exceeds history limit
		this.#trim_to_history_limit();

		return payload;
	}

	/**
	 * Get the latest N payloads of a specific type.
	 *
	 * @param type The payload type to filter by
	 * @param limit Maximum number of payloads to return (defaults to history_limit)
	 * @returns Array of payloads matching the type
	 */
	get_latest_by_type(type: Payload_Type, limit: number = this.history_limit): Array<Payload> {
		return this.items.latest('by_type', type, limit);
	}

	/**
	 * Trims the collection to the maximum allowed size by removing oldest payloads.
	 */
	#trim_to_history_limit(): void {
		// Calculate how many items to remove and use the optimized method
		const excess = this.items.size - this.history_limit;
		if (excess <= 0) return;
		const ids = [];
		for (const payload of this.items.by_id.values()) {
			ids.push(payload.id);
			if (ids.length === excess) break;
		}
		this.items.remove_many(ids);
	}
}
