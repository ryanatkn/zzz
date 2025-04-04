import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Browser_Tabs} from '$routes/tabs/browser_tabs.svelte.js';
import {Browser_Tab_Json} from '$routes/tabs/browser_tab.svelte.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';

export const Browser_Json = Cell_Json.extend({
	edited_url: z.string().default(''),
	tabs: cell_array(
		z.array(Browser_Tab_Json).default(() => []),
		'Browser_Tab',
	),
});

export type Browser_Json = z.infer<typeof Browser_Json>;

export type Browser_Options = Cell_Options<typeof Browser_Json>;

export class Browser extends Cell<typeof Browser_Json> {
	tabs: Browser_Tabs;
	edited_url: string = $state()!;

	constructor(options: Browser_Options) {
		super(Browser_Json, options);

		// Create the tabs instance
		this.tabs = new Browser_Tabs({
			zzz: this.zzz,
		});

		this.decoders = {
			tabs: (tabs) => {
				if (Array.isArray(tabs)) {
					// Add tabs to the browser tabs collection
					for (const tab_json of tabs) {
						this.tabs.add(tab_json);
					}

					// Make sure one tab is selected
					const selected_tab = this.tabs.ordered_tabs.find((tab) => tab.selected);
					if (!selected_tab && this.tabs.ordered_tabs.length > 0) {
						this.tabs.ordered_tabs[0].selected = true;
					}

					// Set the edited URL from the selected tab
					this.edited_url = this.tabs.selected_url;
				}
				return HANDLED;
			},
		};

		this.init();
	}

	navigate_to(url: string): void {
		// Update the selected tab's URL
		this.tabs.update_url(url);
		this.edited_url = url;
	}

	go_back(): void {
		// no-op for now
		return;
	}

	go_forward(): void {
		// no-op for now
		return;
	}

	refresh(): void {
		this.tabs.refresh_selected();
	}

	add_new_tab(): void {
		this.tabs.add_new_tab();
		this.edited_url = this.tabs.selected_url;
	}

	close_tab(index: number): void {
		this.tabs.close(index);
		this.edited_url = this.tabs.selected_url;
	}

	reopen_last_closed_tab(): void {
		this.tabs.reopen_last_closed_tab();
		this.edited_url = this.tabs.selected_url;
	}

	select_tab(index: number): void {
		this.tabs.select(index);
		this.edited_url = this.tabs.selected_url;
	}

	submit_edited_url(): void {
		this.navigate_to(this.edited_url);
	}

	reorder_tab(from_index: number, to_index: number): void {
		this.tabs.reorder_tabs(from_index, to_index);
	}
}

export const Browser_Schema = z.instanceof(Browser);

// Re-export for convenience
export {fake_sites, sample_tabs} from '$routes/tabs/browser_fake_sites.js';
export {Browser_Tab} from '$routes/tabs/browser_tab.svelte.js';
export type {Browser_Tab_Json} from '$routes/tabs/browser_tab.svelte.js';
export {Browser_Tabs} from '$routes/tabs/browser_tabs.svelte.js';
