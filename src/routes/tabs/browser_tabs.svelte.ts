import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_single_index, create_derived_index} from '$lib/indexed_collection_helpers.js';
import {Datetime_Now, Uuid} from '$lib/zod_helpers.js';
import {Cell_Json} from '$lib/cell_types.js';
import {
	Browser_Tab,
	Browser_Tab_Json,
	Browser_Tab_Schema,
} from '$routes/tabs/browser_tab.svelte.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {to_reordered_list} from '$lib/list_helpers.js';
import {fake_sites} from '$routes/tabs/sample_tabs.js';

export const Browser_Tabs_Json = Cell_Json.extend({
	tabs: cell_array(
		z.array(Browser_Tab_Json).default(() => []),
		'Browser_Tab',
	),
	recently_closed_tabs: cell_array(
		z.array(Browser_Tab_Json).default(() => []),
		'Browser_Tab',
	),
});

export type Browser_Tabs_Json = z.infer<typeof Browser_Tabs_Json>;

export type Browser_Tabs_Options = Cell_Options<typeof Browser_Tabs_Json>;

export class Browser_Tabs extends Cell<typeof Browser_Tabs_Json> {
	items: Indexed_Collection<Browser_Tab> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'url',
				extractor: (tab) => tab.url,
				query_schema: z.string(),
				result_schema: Browser_Tab_Schema,
			}),
			create_derived_index({
				key: 'manual_order',
				compute: (collection) => Array.from(collection.by_id.values()),
				result_schema: z.array(Browser_Tab_Schema),
			}),
		],
	});

	/** Ordered array of tabs derived from the `manual_order` index. */
	readonly ordered_tabs: Array<Browser_Tab> = $derived(this.items.derived_index('manual_order'));

	recently_closed_tabs: Array<Browser_Tab> = $state([]);

	selected_tab: Browser_Tab | undefined = $derived(this.ordered_tabs.find((t) => t.selected));

	selected_url: string = $derived(this.selected_tab?.url || '');

	constructor(options: Browser_Tabs_Options) {
		super(Browser_Tabs_Json, options);

		this.decoders = {
			tabs: (tabs) => {
				if (Array.isArray(tabs)) {
					// Clear existing tabs
					this.items.clear();

					// Add tabs from JSON
					for (const tab_json of tabs) {
						const tab = new Browser_Tab({
							zzz: this.zzz,
							json: tab_json,
						});
						this.items.add(tab);
					}
				}
				return HANDLED;
			},
			recently_closed_tabs: (tabs) => {
				if (Array.isArray(tabs)) {
					this.recently_closed_tabs = tabs.map(
						(tab_json) =>
							new Browser_Tab({
								zzz: this.zzz,
								json: tab_json,
							}),
					);
				}
				return HANDLED;
			},
		};

		this.init();
	}

	add(tab_data: Browser_Tab_Json): void {
		// Add new tab to collection
		const tab = new Browser_Tab({
			zzz: this.zzz,
			json: tab_data,
		});
		this.items.add(tab);
	}

	add_new_tab(): void {
		// Deselect all existing tabs
		for (const tab of this.items.by_id.values()) {
			tab.selected = false;
		}

		// Create new tab with embedded content
		this.add({
			id: Uuid.parse(undefined),
			title: 'new tab',
			selected: true,
			url: '~newtab',
			type: 'embedded_html',
			content: fake_sites.new_tab.content,
			refresh_counter: 0,
			created: Datetime_Now.parse(undefined),
			updated: null,
		});
	}

	close(index: number): void {
		const tabs = this.ordered_tabs;
		if (index >= 0 && index < tabs.length) {
			const tab_to_close = tabs[index];
			const was_selected = tab_to_close.selected;

			// Store a copy of the tab before removing it
			this.recently_closed_tabs.push(tab_to_close);

			this.items.remove(tab_to_close.id);

			// If we closed the selected tab and there are other tabs, select the nearest one to the right
			if (was_selected && this.ordered_tabs.length > 0) {
				// Try to select the tab to the right (next index), or the last tab if there's nothing to the right
				const new_index = Math.min(this.ordered_tabs.length - 1, index);
				// Select the tab at the new index
				this.ordered_tabs[new_index].selected = true;
			}
		}
	}

	reopen_last_closed_tab(): void {
		if (this.recently_closed_tabs.length > 0) {
			const tab_to_reopen = this.recently_closed_tabs.pop();
			if (tab_to_reopen) {
				// If the tab was previously selected, deselect all current tabs
				if (tab_to_reopen.selected) {
					for (const tab of this.items.by_id.values()) {
						tab.selected = false;
					}
				}
				this.items.add(tab_to_reopen);
			}
		}
	}

	select(index: number): void {
		const tabs = this.ordered_tabs;
		if (index >= 0 && index < tabs.length) {
			for (let i = 0; i < tabs.length; i++) {
				tabs[i].selected = i === index;
			}
		}
	}

	update_url(url: string): void {
		const selected_tab = this.selected_tab;
		if (selected_tab) {
			selected_tab.url = url;

			// If it's an external URL tab, force a refresh
			if (selected_tab.type === 'external_url') {
				selected_tab.refresh();
			}
		}
	}

	refresh_selected(): void {
		const selected_tab = this.selected_tab;
		if (selected_tab) {
			selected_tab.refresh();
		}
	}

	reorder_tabs(from_index: number, to_index: number): void {
		this.items.indexes.manual_order = to_reordered_list(this.ordered_tabs, from_index, to_index);
	}
}

export const Browser_Tabs_Schema = z.instanceof(Browser_Tabs);
