import {z} from 'zod';

import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_single_index} from '$lib/indexed_collection_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';

export class Browser {
	tabs: Browser_Tabs;
	edited_url: string = $state()!;

	constructor(initial_tabs: Array<Browser_Tab> = []) {
		this.tabs = new Browser_Tabs(initial_tabs);
		this.edited_url = this.tabs.selected_url;
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
}

// Browser tab types and interfaces
export interface Browser_Tab_Base {
	id: Uuid;
	title: string;
	selected: boolean;
	url: string;
	refresh_counter: number; // Add a counter that changes when refresh is needed
}

export interface Raw_Tab extends Browser_Tab_Base {
	type: 'raw';
}

export interface Embedded_HTML_Tab extends Browser_Tab_Base {
	type: 'embedded_html';
	content: string;
}

export interface External_URL_Tab extends Browser_Tab_Base {
	type: 'external_url';
}

// Union type for browser tabs
export type Browser_Tab = Raw_Tab | Embedded_HTML_Tab | External_URL_Tab;

// Fake site content for embedded HTML tabs
export const fake_sites = {
	future: {
		title: 'Zzz in the future',
		url: 'https://www.zzz.software/future',
		content: `
			<article style="padding: 10px;">
				<header>
					<h1>Zzz in the future</h1>
				</header>
				<section style="width: 300px">
					<p>Zzz is a big ambitious project and I don't know what could come of it. Maybe it remains a portfolio item that helps me get a job building similar things, or maybe it'll get traction with some enthusiast users. I can say for certain I won't raise VC or change it from being a permissively licensed open source project.</p>
					<p>In any case I seem to have boundless motivation for it at the moment, so it should continue to develop.</p>
					<p>In terms of roadmap, I plan to work on the browser functionality sometime after the sites proof of concept with basic CMS features, so it'll be a while.</p>
					<p>Head over to <a href="https://github.com/ryanatkn/zzz" target="_blank" rel="noopener">Github</a> to learn more.</p>
				</section>
			</article>
		`,
	},
	new_tab: {
		title: 'new tab',
		url: 'about:newtab',
		content: `
			<div style="padding: 20px; font-family: system-ui;">
				<h1>new tab</h1>
				<ul>
					<li><a href="https://www.zzz.software/about" target="_blank" rel="noopener">about Zzz</a></li>
					<li><a href="https://github.com/ryanatkn/zzz" target="_blank" rel="noopener">source code</a></li>
				</ul>
			</div>
		`,
	},
};

// Browser tabs management
export class Browser_Tabs {
	items: Indexed_Collection<Browser_Tab> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'url',
				extractor: (tab) => tab.url,
				query_schema: z.string(),
				result_schema: z.custom<Browser_Tab>(),
			}),
		],
	});

	all: Array<Browser_Tab> = $derived(this.items.all);
	recently_closed_tabs: Array<Browser_Tab> = $state([]);

	selected_tab: Browser_Tab | undefined = $derived(this.items.all.find((t) => t.selected)); // TODO single index

	selected_url: string = $derived(this.selected_tab?.url || '');

	constructor(initial_tabs?: Array<Browser_Tab>) {
		if (initial_tabs) {
			for (const tab of initial_tabs) {
				this.items.add(tab);
			}
		}
	}

	add(tab: Browser_Tab): void {
		// Add new tab to collection
		this.items.add(tab);
	}

	add_new_tab(): void {
		// Deselect all existing tabs
		for (const tab of this.items.all) {
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
			refresh_counter: 0, // Initialize refresh counter
		});
	}

	close(index: number): void {
		const tabs = this.items.all;
		if (index >= 0 && index < tabs.length) {
			const tab_to_close = tabs[index];
			const was_selected = tab_to_close.selected;

			// Store a copy of the tab before removing it
			this.recently_closed_tabs.push({...tab_to_close});

			this.items.remove(tab_to_close.id);

			// If we closed the selected tab and there are other tabs, select the nearest one to the right
			if (was_selected && tabs.length > 0 && !tabs.some((t) => t.selected)) {
				// Try to select the tab to the right (next index), or the last tab if there's nothing to the right
				const new_index = Math.min(tabs.length - 1, index);
				// Select the tab at the new index
				this.items.all[new_index].selected = true;
			}
		}
	}

	reopen_last_closed_tab(): void {
		if (this.recently_closed_tabs.length > 0) {
			const tab_to_reopen = this.recently_closed_tabs.pop();
			if (tab_to_reopen) {
				// If the tab was previously selected, deselect all current tabs
				if (tab_to_reopen.selected) {
					for (const tab of this.items.all) {
						tab.selected = false;
					}
				}
				this.add(tab_to_reopen);
			}
		}
	}

	select(index: number): void {
		const tabs = this.items.all;
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

			// If it's an external URL tab, force a refresh by cloning the tab
			if (selected_tab.type === 'external_url') {
				const index = this.items.all.indexOf(selected_tab);
				if (index >= 0) {
					this.items.all[index] = {...selected_tab};
				}
			}
		}
	}

	refresh_selected(): void {
		const selected_tab = this.selected_tab;
		if (selected_tab) {
			// Increment the refresh counter to trigger a UI refresh
			selected_tab.refresh_counter = (selected_tab.refresh_counter || 0) + 1;
		}
	}
}
