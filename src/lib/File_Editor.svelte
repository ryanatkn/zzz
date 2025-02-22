<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import type {Source_File} from '@ryanatkn/gro/filer.js';
	import {untrack} from 'svelte';

	import {to_root_path} from '$lib/path.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';

	interface Props {
		// TODO more efficient data structures, reactive source files
		file: Source_File;
		height?: number;
	}

	const {file, height = 600}: Props = $props();

	const dependencies = $derived(Array.from(file.dependencies.values()));
	const dependents = $derived(Array.from(file.dependents.values()));

	const zzz = zzz_context.get();

	// TODO BLOCK on revert save, disable the button

	// TODO hoist this state to `zzz` per file?
	let updated_contents: string = $state(file.contents ?? '');
	let previous_contents: string | null = $state(null);
	let last_save_contents: string = $state(file.contents ?? '');
	// Replace the derived store with a reactive statement
	const is_file_modified = $derived(file.contents !== last_save_contents);

	// Remove updating last_save_contents here so it stays as the saved version
	$effect.pre(() => {
		const f = file;
		updated_contents = untrack(() => f.contents) ?? '';
		last_save_contents = untrack(() => f.contents) ?? '';
	});

	// TODO BLOCK add the slidey X for the delete button below
</script>

<div class="row size_xl word_break_break_all">
	<span class="size_xl3 mr_md">🗎</span>
	{to_root_path(file.id)}
</div>

<div>
	<Copy_To_Clipboard text={file.contents} />
	contents {#if file.contents === null}
		null
	{:else}
		({file.contents.length} chars)
	{/if}
</div>
<div class="flex flex_wrap">
	<div class="flex_1 width_md min_width_sm">
		<textarea style:height="{height}px" bind:value={updated_contents}></textarea>
	</div>
	<pre
		style:height="{height}px"
		class="flex_1 fg_1 radius_sm p_md width_md min_width_sm"
		style:min-width="var(--width_sm)">{file.contents}</pre>
</div>
<div class="flex justify_content_space_between">
	<button
		class="color_a"
		type="button"
		disabled={updated_contents === file.contents}
		onclick={() => {
			const previous = file.contents ?? '';
			zzz.update_file(file.id, updated_contents);
			// Update file.contents to the new value and set last_save_contents to the previous version
			file.contents = updated_contents;
			last_save_contents = previous;
			console.log('saved:', {
				previous,
				current: file.contents,
				last_save_contents,
				is_file_modified,
			});
		}}>save file</button
	>
	<div class="flex">
		<button
			type="button"
			disabled={updated_contents === file.contents}
			onclick={() => {
				previous_contents = updated_contents;
				updated_contents = file.contents ?? '';
			}}>discard changes</button
		>
		<button
			type="button"
			disabled={previous_contents === null}
			onclick={() => {
				updated_contents = previous_contents ?? '';
				previous_contents = null;
			}}>redo changes</button
		>
		<button
			type="button"
			disabled={!is_file_modified}
			onclick={() => {
				previous_contents = updated_contents;
				updated_contents = last_save_contents;
			}}>revert save</button
		>
	</div>
	<Confirm_Button onclick={() => zzz.delete_file(file.id)} button_attrs={{class: 'color_c'}}>
		{#snippet children()}
			delete file
		{/snippet}
	</Confirm_Button>
</div>

{#if dependencies.length}
	<h2>
		{dependencies.length}
		{#if dependencies.length === 1}dependency{:else}dependencies{/if}
	</h2>
	<div class="dep_list">
		{#each dependencies as dependency (dependency.id)}
			<div>{to_root_path(dependency.id)}</div>
		{/each}
	</div>
{/if}
{#if dependents.length}
	<h2>
		{dependents.length}
		dependent{#if dependents.length !== 1}s{/if}
	</h2>
	<div class="dep_list">
		{#each dependents as dependent (dependent.id)}
			<div>{to_root_path(dependent.id)}</div>
		{/each}
	</div>
{/if}

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
