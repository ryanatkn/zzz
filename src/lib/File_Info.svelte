<script lang="ts">
	import Details from '@ryanatkn/fuz/Details.svelte';
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Text_Entry from '@ryanatkn/fuz/Contextmenu_Text_Entry.svelte';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import type {Source_File} from '@ryanatkn/gro/filer.js';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';

	import {to_base_path} from '$lib/path.js';
	import File_Editor from '$lib/File_Editor.svelte';

	interface Props {
		// TODO more efficient data structures, reactive source files
		file: Source_File;
	}

	const {file}: Props = $props();

	const dependencies = $derived(Array.from(file.dependencies.values()));
	const dependents = $derived(Array.from(file.dependents.values()));

	let show_editor = $state(false);

	// TODO refactor
	let view_with: 'summary' | 'details' = $state('summary');
</script>

<div use:contextmenu_action={contextmenu_entries}>
	<button type="button">{to_base_path(file.id)}</button>

	<div>{view_with}</div>

	deps ({dependencies.length} dependencies, {dependents.length} dependents)
	<h2>dependencies</h2>
	<div class="dep_list">
		{#each dependencies as dependency (dependency.id)}
			<div>{to_base_path(dependency.id)}</div>
		{/each}
	</div>
	<h2>
		{#if !dependents.length}no{' '}{/if}dependents
	</h2>
	{#if dependents.length > 0}
		<div class="dep_list">
			{#each dependents as dependent (dependent.id)}
				<button type="button" onclick={() => (show_editor = true)}
					>{to_base_path(dependent.id)}</button
				>
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
</div>

{#if show_editor}
	<Dialog onclose={() => (show_editor = false)}>
		<!-- TODO expand width, might need to change `Dialog` -->
		<div class="bg p_md radius_sm width_md">
			<File_Editor {file} />
			<button type="button" onclick={() => (show_editor = false)}>close</button>
			{@render file_contents()}
		</div>
	</Dialog>
{/if}

{#snippet file_contents()}
	contents {#if file.contents === null}
		null
	{:else}
		({file.contents.length} characters)
	{/if}
{/snippet}

{#snippet contextmenu_entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}?{/snippet}
		View with
		{#snippet menu()}
			<!-- TODO `disabled` property to the entry -->
			<Contextmenu_Entry run={() => (view_with = 'summary')}>
				{#snippet icon()}🐈‍⬛{/snippet}
				Summary
			</Contextmenu_Entry>
			<Contextmenu_Entry run={() => (view_with = 'details')}>
				{#snippet icon()}🐈‍⬛{/snippet}
				Details
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
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
