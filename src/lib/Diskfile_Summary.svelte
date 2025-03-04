<script lang="ts">
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import {to_root_path} from '$lib/path.js';

	interface Props {
		file: Diskfile;
	}

	const {file}: Props = $props();
</script>

<div class="file_summary row justify_content_space_between">
	<div class="flex flex_1 overflow_auto">
		<div class="size_xl">🗎</div>
		<div class="px_lg ellipsis">{to_root_path(file.id)}</div>
	</div>
	<div
		style:width="70px"
		class="shrink_0 text_align_right"
		title="{file.dependencies_count} dependenc{file.dependencies_count === 1 ? 'y' : 'ies'}"
	>
		{file.dependencies_count} ⇉
	</div>
	<div
		style:width="70px"
		class="shrink_0 text_align_right"
		title="{file.dependents_count} dependent{file.dependents_count === 1 ? '' : 's'}"
	>
		{file.dependents_count} ⇇
	</div>
	<div style:width="130px" class="shrink_0 text_align_right pr_md">
		{#if file.contents !== null}
			{file.content_length}
			{#if file.content_length === 1}character{:else}chars{/if}
		{/if}
	</div>
</div>

<style>
	.file_summary:hover {
		background: var(--fg_0);
	}
</style>
