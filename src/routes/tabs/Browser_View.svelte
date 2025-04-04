<script lang="ts">
	import {swallow, is_editable} from '@ryanatkn/belt/dom.js';
	import type {Snippet} from 'svelte';

	import {
		GLYPH_PLACEHOLDER,
		GLYPH_ADD,
		GLYPH_REFRESH,
		GLYPH_ARROW_RIGHT,
		GLYPH_ARROW_LEFT,
	} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import type {Browser} from '$routes/tabs/browser.svelte.js';
	import Browser_Tab_Content from '$routes/tabs/Browser_Tab_Content.svelte';
	import Browser_Tab_Listitem from '$routes/tabs/Browser_Tab_Listitem.svelte';
	import {Reorderable} from '$lib/reorderable.svelte.js';

	interface Props {
		browser: Browser;
		children: Snippet;
	}

	const {browser, children}: Props = $props();

	const tabs_reorderable = new Reorderable({item_class: null}); // remove the normal reorderable item styling
</script>

<svelte:window
	onkeydown={(e) => {
		if (is_editable(e.target)) {
			return;
		}

		// We can't override the actual browser keyboard shortcuts here, so we use `q` instead of `t`.
		// Keyboard shortcuts also don't work when an iframe is focused.
		// Both of these issues will be fixed in Zzz's eventual browser that'll run as a native app.

		// ctrl+q: New tab
		if (e.ctrlKey && !e.shiftKey && !e.altKey && e.key === 'q') {
			swallow(e);
			browser.add_new_tab();
		}

		// ctrl+shift+q: Reopen last closed tab
		if (e.ctrlKey && e.shiftKey && e.key === 'Q') {
			swallow(e);
			browser.reopen_last_closed_tab();
		}

		// ctrl+alt+q: Close current tab
		if (e.ctrlKey && e.altKey && !e.shiftKey && e.key === 'q') {
			swallow(e);
			const index = browser.tabs.ordered_tabs.findIndex((t) => t.selected);
			if (index !== -1) {
				browser.close_tab(index);
			}
		}
		// TODO add other global keyboard shortcuts
	}}
/>

<div class="browser_container">
	<!-- Browser Chrome/Header -->
	<div class="browser_chrome">
		<!-- Tab Bar -->
		<ul
			class="browser_tab_bar unstyled flex overflow_x_auto overflow_y_hidden scrollbar_width_thin"
			use:tabs_reorderable.list={{
				onreorder: (from_index, to_index) => browser.reorder_tab(from_index, to_index),
			}}
		>
			{#each browser.tabs.ordered_tabs as tab, index (tab.id)}
				<li class="flex" use:tabs_reorderable.item={{index}}>
					<Browser_Tab_Listitem
						{tab}
						{index}
						onselect={(index) => browser.select_tab(index)}
						onclose={(index) => browser.close_tab(index)}
					/>
				</li>
			{/each}
			<div class="p_sm">
				<button
					type="button"
					class="plain ml_xs radius_md"
					style:width="32px"
					style:min-width="32px"
					style:height="32px"
					style:min-height="32px"
					onclick={() => browser.add_new_tab()}
					title="new tab"
				>
					<Glyph icon={GLYPH_ADD} />
				</button>
			</div>
		</ul>

		<!-- Navigation Controls & Address Bar -->
		<div class="browser_controls flex gap_sm p_xs4">
			<div class="browser_nav_buttons flex gap_xs">
				<button
					type="button"
					class="icon_button plain p_xs radius_lg"
					title="back"
					onclick={() => browser.go_back()}
					disabled
				>
					{GLYPH_ARROW_LEFT}
				</button>
				<button
					type="button"
					class="icon_button plain p_xs radius_lg"
					title="forward"
					onclick={() => browser.go_forward()}
					disabled
				>
					{GLYPH_ARROW_RIGHT}
				</button>
				<button
					type="button"
					class="icon_button plain p_xs radius_lg"
					title="refresh"
					onclick={() => browser.refresh()}
				>
					{GLYPH_REFRESH}
				</button>
			</div>

			<!-- Address Bar -->
			<div class="browser_address_bar flex_1">
				<input
					type="text"
					bind:value={browser.edited_url}
					class="w_100 plain radius_lg"
					onkeypress={(e) => {
						if (e.key === 'Enter') {
							browser.submit_edited_url();
						}
					}}
					placeholder={GLYPH_PLACEHOLDER}
				/>
			</div>

			<!-- Main Menu -->
			<div class="flex gap_xs">
				<button
					type="button"
					class="icon_button plain p_xs"
					title="main menu"
					onclick={() => {
						// eslint-disable-next-line no-alert
						alert('not yet, thanks for clicking');
					}}>☰</button
				>
			</div>
		</div>
	</div>

	<!-- Browser Content Area (Shows selected tab content) -->
	<div class="browser_content">
		{#if browser.tabs.selected_tab}
			<Browser_Tab_Content tab={browser.tabs.selected_tab}>
				{@render children()}
			</Browser_Tab_Content>
		{/if}
	</div>
</div>

<style>
	.browser_container {
		height: 100%;
		width: 100%;
		display: flex;
		flex-direction: column;
		border-left: 1px solid var(--border_color_1);
	}

	.browser_chrome {
		border-bottom: 1px solid var(--border_color_1);
		flex-shrink: 0;
	}

	.browser_tab_bar {
		border-bottom: 1px solid var(--border_color_1);
	}

	.browser_content {
		flex: 1;
		overflow: auto;
		position: relative;
	}

	.browser_address_bar input {
		background: transparent;
	}
</style>
