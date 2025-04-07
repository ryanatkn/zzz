import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid, Uuid_Required} from '$lib/zod_helpers.js';
import {Cell_Json} from '$lib/cell_types.js';
import type {Diskfile} from '$lib/diskfile.svelte.js';
import type {Diskfile_Tabs} from '$lib/diskfile_tabs.svelte.js';

export const Diskfile_Tab_Json = Cell_Json.extend({
	diskfile_id: Uuid_Required,
});
export type Diskfile_Tab_Json = z.infer<typeof Diskfile_Tab_Json>;

export interface Diskfile_Tab_Options extends Cell_Options<typeof Diskfile_Tab_Json> {
	tabs: Diskfile_Tabs;
}

export class Diskfile_Tab extends Cell<typeof Diskfile_Tab_Json> {
	diskfile_id: Uuid = $state()!;

	/**
	 * Reference to the parent tabs collection,
	 * allowing us to have collection-derived data,
	 * at the cost of requiring exactly 1 parent.
	 *
	 * This pattern is somewhat experimental -
	 * the idea is it's more declarative to have things
	 * like the "preview" or "selected" tabs be state on the collection,
	 * so it doesn't need to be separately managed as state on each tab.
	 */
	readonly tabs: Diskfile_Tabs;

	/** Derived from parent collection's state */
	readonly is_preview: boolean = $derived.by(() => this.tabs.preview_tab_id === this.id);

	/** Derived from parent collection's state */
	readonly is_selected: boolean = $derived.by(() => this.tabs.selected_tab_id === this.id);

	readonly diskfile: Diskfile | undefined = $derived(
		this.zzz.diskfiles.items.by_id.get(this.diskfile_id),
	);

	constructor(options: Diskfile_Tab_Options) {
		super(Diskfile_Tab_Json, options);
		this.tabs = options.tabs;
		this.init();
	}
}

export const Diskfile_Tab_Schema = z.instanceof(Diskfile_Tab);
