<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import type {Source_File} from '@ryanatkn/gro/filer.js';

	import {to_base_path} from '$lib/path.js';
	import {zzz_context} from './zzz.svelte.js';

	interface Props {
		// TODO more efficient data structures, reactive source files
		file: Source_File;
		height?: number;
	}

	const {file, height = 600}: Props = $props();

	const dependencies = $derived(Array.from(file.dependencies.values()));
	const dependents = $derived(Array.from(file.dependents.values()));

	const zzz = zzz_context.get();

	let updated_contents = $state(file.contents ?? '');
</script>

<div class="row size_xl"><span class="size_xl3 mr_md">🗎</span> {to_base_path(file.id)}</div>

<h2>
	{#if !dependencies.length}no{:else}{dependencies.length}{/if}
	{dependencies.length === 1 ? 'dependency' : 'dependencies'}
</h2>
{#if dependencies.length > 0}
	<div class="dep_list">
		{#each dependencies as dependency (dependency.id)}
			<div>{to_base_path(dependency.id)}</div>
		{/each}
	</div>
{/if}
<h2>
	{#if !dependents.length}no{:else}{dependents.length}{/if}
	{dependents.length === 1 ? 'dependent' : 'dependents'}
</h2>
{#if dependents.length > 0}
	<div class="dep_list">
		{#each dependents as dependent (dependent.id)}
			<div>{to_base_path(dependent.id)}</div>
		{/each}
	</div>
{/if}

<div>
	<Copy_To_Clipboard text={file.contents} />
	contents {#if file.contents === null}
		null
	{:else}
		({file.contents.length} chars)
	{/if}
</div>
<div class="editor">
	<div class="flex_1">
		<div>
			<textarea style:height="{height}px" bind:value={updated_contents}></textarea>
		</div>
		<button
			type="button"
			disabled={updated_contents === file.contents}
			onclick={() => {
				zzz.update_file(file.id, updated_contents);
			}}>save</button
		>
	</div>
	<pre style:height="{height}px" class="flex_1 fg_1 radius_sm p_md">{file.contents}</pre>
</div>

<style>
	.editor {
		display: flex;
		align-items: flex-start;
	}

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
