<script lang="ts">
	import type {Source_File} from '@ryanatkn/gro/filer.js';

	import File_List from '$lib/File_List.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import File_Explorer from '$lib/File_Explorer.svelte';
	import Unicode_Icon from '$lib/Unicode_Icon.svelte';
	import {SYMBOL_FILE} from '$lib/constants.js';

	const zzz = zzz_context.get();

	const files = $derived(Array.from(zzz.files_by_id.values()).filter((file) => !file.external));

	// TODO BLOCK shouldnt be needed
	const files_map: Map<string, Source_File> = $derived(new Map(files.map((f) => [f.id, f])));
	let selected_file_id = $state<string | null>(null);
	const handle_file_selection = (file: Source_File): void => {
		selected_file_id = file.id;
	};

	// TODO BLOCK show path

	// TODO BLOCK name for "File_Explorer" and "File_List" parent component?
</script>

<div class="flex p_sm">
	<div class="shrink_0">
		<header class="size_xl mb_md"><Unicode_Icon icon={SYMBOL_FILE} /> File Explorer</header>
		<File_Explorer
			files={files_map}
			{selected_file_id}
			onselect={(file) => handle_file_selection(file)}
		/>
	</div>
	<div class="p_md">
		<header class="size_xl mb_md"><Unicode_Icon icon={SYMBOL_FILE} /> Files</header>
		<File_List {files} />
	</div>
</div>
