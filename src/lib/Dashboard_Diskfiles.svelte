<script lang="ts">
	import {swallow, is_editable} from '@ryanatkn/belt/dom.js';

	import {zzz_context} from '$lib/frontend.svelte.js';
	import Diskfile_Explorer from '$lib/Diskfile_Explorer.svelte';
	import Diskfile_Editor_View from '$lib/Diskfile_Editor_View.svelte';
	import Diskfile_Tab_Listitem from '$lib/Diskfile_Tab_Listitem.svelte';
	import {Reorderable} from '$lib/reorderable.svelte.js';
	import Diskfile_Picker_Dialog from '$lib/Diskfile_Picker_Dialog.svelte';

	const app = zzz_context.get();
	const {diskfiles} = app;
	const {editor} = diskfiles;

	const tabs_reorderable = new Reorderable({item_class: null}); // remove the normal reorderable item styling

	const selected_tab = $derived(editor.tabs.selected_tab);
	const selected_diskfile = $derived(
		selected_tab ? diskfiles.items.by_id.get(selected_tab.diskfile_id) : undefined,
	);

	let show_diskfile_picker = $state(false);
</script>

<svelte:window
	onkeydown={(e) => {
		if (is_editable(e.target)) {
			return;
		}

		// ctrl+q: Close tab
		if (e.ctrlKey && !e.shiftKey && !e.altKey && e.key === 'q') {
			swallow(e);
			const selected_tab = editor.tabs.selected_tab;
			if (selected_tab) {
				editor.close_tab(selected_tab.id);
			}
		}

		// ctrl+shift+Q: Reopen last closed tab
		if (e.ctrlKey && e.shiftKey && e.key === 'Q') {
			swallow(e);
			editor.reopen_last_closed_tab();
		}
	}}
/>

<div class="h_100 display_flex">
	<div class="h_100 overflow_hidden width_sm">
		<Diskfile_Explorer />
	</div>

	<div class="flex_1 column overflow_auto h_100">
		<!-- Tab Bar -->
		<ul
			class="unstyled display_flex overflow_x_auto scrollbar_width_thin"
			use:tabs_reorderable.list={{
				onreorder: (from_index, to_index) => editor.reorder_tabs(from_index, to_index),
			}}
		>
			{#each editor.tabs.ordered_tabs as tab, index (tab.id)}
				<li class="display_flex py_xs3 px_xs4">
					<div class="display_flex" use:tabs_reorderable.item={{index}}>
						<Diskfile_Tab_Listitem
							{tab}
							onselect={(tab) => editor.select_tab(tab.id)}
							onclose={(tab) => editor.close_tab(tab.id)}
							onopen={(tab) => editor.open_tab(tab.id)}
						/>
					</div>
				</li>
			{/each}
		</ul>

		<!-- Editor content area -->
		{#if selected_tab}
			{#if selected_diskfile}
				<Diskfile_Editor_View
					diskfile={selected_diskfile}
					onmodified={(diskfile_id) => editor.handle_file_modified(diskfile_id)}
				/>
			{:else}
				<!-- TODO think this through - maybe the tabs should be more flexible than 1:1 with a diskfile? maybe `Diskfile_Editor_View` should have UI to create a file if there is none? -->
				<div class="display_flex align_items_center justify_content_center h_100">
					<p>Something went wrong, this tab has no diskfile</p>
				</div>
			{/if}
		{:else}
			<div class="display_flex align_items_center justify_content_center h_100">
				<p>
					<button
						type="button"
						class="inline"
						onclick={() => {
							show_diskfile_picker = true;
						}}>select</button
					> a file from the list to view and edit its content
				</p>
			</div>
		{/if}
	</div>
</div>

<Diskfile_Picker_Dialog
	bind:show={show_diskfile_picker}
	onpick={(diskfile) => {
		if (!diskfile) return false;
		editor.open_diskfile(diskfile.id);
		return true;
	}}
/>
