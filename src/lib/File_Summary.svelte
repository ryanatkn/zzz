<script lang="ts">
	import type {Source_File} from '@ryanatkn/gro/filer.js';

	import {to_base_path} from '$lib/path.js';

	interface Props {
		// TODO more efficient data structures, reactive source files
		file: Source_File;
	}

	const {file}: Props = $props();

	const dependencies = $derived(Array.from(file.dependencies.values()));
	const dependents = $derived(Array.from(file.dependents.values()));
</script>

<div class="file_summary row justify_content_space_between">
	<div class="row flex_1 overflow_auto">
		<div class="size_xl">🗎</div>
		<div class="px_lg ellipsis">{to_base_path(file.id)}</div>
	</div>
	<div
		style:width="70px"
		class="shrink_0 text_align_right"
		title="{dependencies.length} dependenc{dependencies.length === 1 ? 'y' : 'ies'}"
	>
		{dependencies.length} ⇉
	</div>
	<div
		style:width="70px"
		class="shrink_0 text_align_right"
		title="{dependents.length} dependent{dependents.length === 1 ? '' : 's'}"
	>
		{dependents.length} ⇇
	</div>
	<div style:width="130px" class="shrink_0 text_align_right pr_md">
		{#if file.contents !== null}
			{file.contents.length}
			{#if file.contents.length === 1}character{:else}chars{/if}
		{/if}
	</div>
</div>

<style>
	.file_summary:hover {
		background: var(--fg_0);
	}
</style>
