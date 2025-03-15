import {page} from '$app/state';
import {z} from 'zod';
import {goto} from '$app/navigation';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {BROWSER} from 'esm-env';

/**
 * Schema for URL parameters manager
 */
export const Url_Params_Json = z.object({
	// No persisted state needed
});
export type Url_Params_Json = z.infer<typeof Url_Params_Json>;

export interface Url_Params_Options extends Cell_Options<typeof Url_Params_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

/**
 * Manages URL parameter synchronization for various entities
 */
export class Url_Params extends Cell<typeof Url_Params_Json> {
	// TODO BLOCK maybe move to a base class? `add_cleanup` that lazily instantiates an array of them? and a destroy function that's called for children?
	cleanup: () => void;
	// override destroy(): void {
	// 	this.cleanup();
	// }

	constructor(options: Url_Params_Options) {
		super(Url_Params_Json, options);
		this.init();

		// TODO this is messy but it's fine for now, ideally it's more explicit/robost than being in the constructor
		this.cleanup = $effect.root(() => {
			$effect(() => {
				// TODO probably iterate over searchParams instead instead of the per-key checks below
				page.url.search;

				// Sync chat selection
				this.#sync_param('chat', this.zzz.chats.items.by_id, (id) => {
					this.zzz.chats.select(id);
				});

				// Sync prompt selection
				this.#sync_param('prompt', this.zzz.prompts.items.by_id, (id) => {
					this.zzz.prompts.select(id);
				});

				// Sync file selection
				this.#sync_param('file', this.zzz.diskfiles.items.by_id, (id) => {
					this.zzz.diskfiles.select(id);
				});
			});
		});
	}

	/**
	 * Update URL with parameter for the selected entity
	 * @param param_name Name of the URL parameter
	 * @param id UUID of the selected entity
	 */
	async update_url(param_name: string, id: Uuid): Promise<void> {
		if (!BROWSER) return;
		const url = new URL(window.location.href);
		url.searchParams.set(param_name, id);
		return goto(url);
	}

	/**
	 * Generic method to sync a URL parameter with an entity selection
	 * @param param_name Name of the URL parameter
	 * @param collection Map of entities by ID
	 * @param select_callback Callback to execute when selecting an entity
	 */
	#sync_param(
		param_name: string,
		collection: Map<Uuid, any>,
		select_callback: (id: Uuid) => void,
	): void {
		const param_value = page.url.searchParams.get(param_name);
		if (!param_value) return;

		const parsed_uuid = Uuid.safeParse(param_value);
		if (parsed_uuid.success && collection.has(parsed_uuid.data)) {
			select_callback(parsed_uuid.data);
		}
	}
}
