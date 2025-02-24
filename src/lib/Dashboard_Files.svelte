<script lang="ts">
	import type {Source_File} from '@ryanatkn/gro/filer.js';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import File_Explorer from '$lib/File_Explorer.svelte';
	import File_Editor from '$lib/File_Editor.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {GLYPH_FILE} from '$lib/constants.js';

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

	// TODO BLOCK show path

	// TODO BLOCK name for "File_Explorer" and "File_List" parent component?
</script>

<div class="h_100 flex p_sm gap_md overflow_hidden">
	<div class="width_sm shrink_0 overflow_auto">
		<header class="size_xl mb_md">
			<h1 class="mb_0"><Text_Icon icon={GLYPH_FILE} /> files</h1>
		</header>
		<File_Explorer
			files={files_map}
			{selected_file_id}
			onselect={(file) => handle_file_selection(file)}
		/>
	</div>
	<div class="flex_1 overflow_auto">
		{#if selected_file}
			<File_Editor file={selected_file} />
		{/if}
	</div>
</div>
