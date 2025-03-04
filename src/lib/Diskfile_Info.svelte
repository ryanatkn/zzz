<script lang="ts">
	import Details from '@ryanatkn/fuz/Details.svelte';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';

	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import {to_root_path} from '$lib/path.js';

	interface Props {
		file: Diskfile;
	}

	const {file}: Props = $props();

	// TODO BLOCK remove the the Array.from() calls below
</script>

<div class="row size_xl"><span class="size_xl3 mr_md">🗎</span> {to_root_path(file.id)}</div>

<p>
	deps (
	{file.dependencies_count}
	{#if file.dependencies_count === 1}dependency{:else}dependency{/if} and
	{file.dependents_count}
	{#if file.dependents_count === 1}dependent{:else}dependents{/if}
	)
</p>

<h2>dependencies</h2>
<div class="dep_list">
	{#each Array.from(file.dependencies.keys()) as dependency_id (dependency_id)}
		<div>{to_root_path(dependency_id)}</div>
	{/each}
</div>
<h2>
	{#if !file.has_dependents}no{' '}{/if}dependents
</h2>
{#if file.has_dependents}
	<div class="dep_list">
		{#each Array.from(file.dependents.keys()) as dependent_id (dependent_id)}
			{to_root_path(dependent_id)}
		{/each}
	</div>
{/if}
<div class="row">
	<Copy_To_Clipboard text={file.contents} />
	<Details>
		{#snippet summary()}{@render file_contents()}
		{/snippet}
		<div class="flex_1">{file.contents}</div>
	</Details>
</div>

{#snippet file_contents()}
	contents {#if file.contents === null}
		null
	{:else}
		({file.content_length} chars)
	{/if}
{/snippet}

<style>
	.dep_list {
		width: 100%;
		display: grid;
		/* TODO make them fill the available space tiling horizontally but not wrapping the widest item.
		This makes them all collapse down on each other.
		*/
		/* grid-template-columns: repeat(auto-fill, minmax(0, 1fr)); */
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 10px;
	}
</style>
