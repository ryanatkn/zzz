<script lang="ts">
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Diskfile_Explorer from '$lib/Diskfile_Explorer.svelte';
	import Diskfile_Editor from '$lib/Diskfile_Editor.svelte';

	const zzz = zzz_context.get();

	// TODO BLOCK shouldn't be needed
	const files = $derived(zzz.files.files.filter((file) => !file.external));

	// TODO BLOCK shouldnt be needed
	const files_map: Map<string, Diskfile> = $derived(new Map(files.map((f) => [f.id, f])));
	let selected_file_id: string | null = $state(null);
	const selected_file: Diskfile | null = $derived(
		selected_file_id && (files_map.get(selected_file_id) ?? null),
	);

	// TODO BLOCK open directories and show their paths in a list on the left (or panel above, configurable I guess)
	// TODO BLOCK name for "Diskfile_Explorer" and "Diskfile_List" parent component?
	// TODO probably show a history of the last N files opened, click to reopen (do this after changing to links)
</script>

<div class="h_100 flex">
	<div class="h_100 overflow_hidden width_sm">
		<Diskfile_Explorer
			onselect={(file) => {
				selected_file_id = file.id;
			}}
		/>
	</div>

	<div class="flex_1 column p_md overflow_y_auto h_100">
		{#if selected_file}
			<Diskfile_Editor file={selected_file} />
		{:else}
			<div class="flex align_items_center justify_content_center h_100">
				<p>Select a file from the list to view and edit its contents</p>
			</div>
		{/if}
	</div>
</div>
