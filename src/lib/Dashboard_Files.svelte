<script lang="ts">
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Diskfile_Explorer from '$lib/Diskfile_Explorer.svelte';
	import Diskfile_Editor from '$lib/Diskfile_Editor.svelte';

	const zzz = zzz_context.get();
	const {diskfiles} = zzz;

	// TODO BLOCK open directories and show their paths in a list on the left (or panel above, configurable I guess)
	// TODO BLOCK name for "Diskfile_Explorer" and "Diskfile_List" parent component?
	// TODO probably show a history of the last N files opened, click to reopen (do this after changing to links)
</script>

<div class="h_100 flex">
	<div class="h_100 overflow_hidden width_sm">
		<Diskfile_Explorer
			onselect={(file) => {
				diskfiles.select_file(file.id);
			}}
		/>
	</div>

	<div class="flex_1 column overflow_auto h_100">
		{#if diskfiles.selected_file}
			<Diskfile_Editor file={diskfiles.selected_file} />
		{:else}
			<div class="flex align_items_center justify_content_center h_100">
				<p>Select a file from the list to view and edit its contents</p>
			</div>
		{/if}
	</div>
</div>
