<script lang="ts">
	import type {Source_File} from '@ryanatkn/gro/filer.js';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Diskfile_Explorer from '$lib/Diskfile_Explorer.svelte';
	import Diskfile_Editor from '$lib/Diskfile_Editor.svelte';
	// import {Scrollable} from '$lib/scrollable.svelte.js';

	const zzz = zzz_context.get();

	const files = $derived(Array.from(zzz.files.by_id.values()).filter((file) => !file.external));

	// TODO BLOCK shouldnt be needed
	const files_map: Map<string, Source_File> = $derived(new Map(files.map((f) => [f.id, f])));
	let selected_file_id: string | null = $state(null);
	const selected_file: Source_File | null = $derived(
		selected_file_id && (files_map.get(selected_file_id) ?? null),
	);
	const handle_file_selection = (file: Source_File): void => {
		selected_file_id = file.id;
	};

	// Create scrolled instances for sidebar and content areas
	// const sidebar_scrollable = new Scrollable();

	// TODO BLOCK open directories and show their paths in a list on the left (or panel above, configurable I guess)

	// TODO BLOCK name for "Diskfile_Explorer" and "Diskfile_List" parent component?

	// TODO probably show a history of the last N files opened, click to reopen (do this after changing to links)
</script>

<div class="h_100 flex">
	<div class="h_100 overflow_hidden width_sm">
		<Diskfile_Explorer
			files={files_map}
			{selected_file_id}
			onselect={(file) => handle_file_selection(file)}
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
