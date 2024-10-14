<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
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

<div class="size_xl">{to_base_path(file.id)}</div>

<p>
	contents {#if file.contents === null}
		null
	{:else}
		({file.contents.length} characters)
	{/if}
</p>
<p>
	{dependencies.length}
	{#if dependencies.length === 1}dependency{:else}dependency{/if} and
	{dependents.length}
	{#if dependents.length === 1}dependent{:else}dependents{/if}
</p>
<div class="row">
	<Copy_To_Clipboard text={file.contents} />
	{#if file.contents !== null}
		<div class="flex_1">{file.contents.length} chars</div>
	{/if}
</div>
