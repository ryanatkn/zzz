<script lang="ts">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import type {Source_File} from '@ryanatkn/gro/filer.js';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';

	import File_Editor from '$lib/File_Editor.svelte';
	import File_Info from '$lib/File_Info.svelte';
	import File_Summary from '$lib/File_Summary.svelte';

	interface Props {
		// TODO more efficient data structures, reactive source files
		file: Source_File;
	}

	const {file}: Props = $props();

	let show_editor = $state(false);

	// TODO refactor
	let view_with: 'summary' | 'info' = $state('summary');
</script>

<div class="file_view" use:contextmenu_action={contextmenu_entries}>
	{#if view_with === 'summary'}
		<File_Summary {file} />
	{:else}
		<File_Info {file} />
	{/if}
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
		({file.contents.length} chars)
	{/if}
{/snippet}

{#snippet contextmenu_entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}>{/snippet}
		View with
		{#snippet menu()}
			<!-- TODO `disabled` property to the entry -->
			<Contextmenu_Entry run={() => (view_with = 'summary')}>
				{#snippet icon()}{#if view_with === 'summary'}{'>'}{/if}{/snippet}
				<span>Summary</span>
			</Contextmenu_Entry>
			<Contextmenu_Entry run={() => (view_with = 'info')}>
				{#snippet icon()}{#if view_with === 'info'}{'>'}{/if}{/snippet}
				<span>Info</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
	<!-- TODO maybe show disabled? -->
	{#if file.contents !== null}
		<Contextmenu_Entry run={() => void navigator.clipboard.writeText(file.contents!)}>
			{#snippet icon()}📋{/snippet}
			<span>Copy {file.contents.length} chars</span>
		</Contextmenu_Entry>
	{/if}
{/snippet}
