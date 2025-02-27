<script lang="ts">
	import type {Source_File} from '@ryanatkn/gro/filer.js';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import File_Explorer from '$lib/File_Explorer.svelte';
	import File_Editor from '$lib/File_Editor.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {GLYPH_FILE} from '$lib/constants.js';
	import {Scrollable} from '$lib/scrollable.svelte.js';

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
	const sidebar_scrollable = new Scrollable();

	// TODO BLOCK open directories and show their paths in a list on the left (or panel above, configurable I guess)

	// TODO BLOCK name for "File_Explorer" and "File_List" parent component?

	// TODO probably show a history of the last N files opened, click to reopen (do this after changing to links)
</script>

<div class="h_100 flex gap_md">
	<div class="h_100 column overflow_hidden">
		<header class="bg p_md size_lg" use:sidebar_scrollable.target>
			<!-- TODO size_lg shouldnt be needed after the Moss --size change -->
			<Text_Icon icon={GLYPH_FILE} size="var(--size_lg)" /> files
		</header>
		<div class="flex_1 width_sm overflow_auto" use:sidebar_scrollable.container>
			<File_Explorer
				files={files_map}
				{selected_file_id}
				onselect={(file) => handle_file_selection(file)}
			/>
		</div>
	</div>
	<div class="flex_1 overflow_auto">
		{#if selected_file}
			<File_Editor file={selected_file} />
		{/if}
	</div>
</div>
