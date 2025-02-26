<script lang="ts">
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import type {Source_File} from '@ryanatkn/gro/filer.js';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';
	import {slide} from 'svelte/transition';

	import File_Editor from '$lib/File_Editor.svelte';
	import File_Info from '$lib/File_Info.svelte';
	import File_Summary from '$lib/File_Summary.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_REMOVE} from '$lib/constants.js';

	interface Props {
		// TODO more efficient data structures, reactive source files
		file: Source_File;
	}

	const {file}: Props = $props();

	// TODO refactor
	type File_View_Type = 'summary' | 'info' | 'editor';
	let view_with_prev: File_View_Type = $state('summary');
	let view_with: File_View_Type = $state('summary'); // TODO `selection` class pattern instead? `new Selection('summary')`

	const File_View_Component = $derived(
		view_with === 'summary' ? File_Summary : view_with === 'info' ? File_Info : File_Editor,
	);

	const update_view_with = (v: File_View_Type) => {
		view_with_prev = view_with;
		view_with = v;
	};

	const zzz = zzz_context.get();

	// TODO BLOCK show content in the right panel for the selected file
</script>

<div class="file_view" use:contextmenu_action={contextmenu_entries}>
	{#key File_View_Component}
		<div transition:slide>
			<File_View_Component {file} />
		</div>
	{/key}
</div>

{#snippet contextmenu_entries()}
	{#if view_with !== 'editor'}
		<Contextmenu_Entry
			run={() => {
				update_view_with('editor');
			}}
		>
			{#snippet icon()}🗎{/snippet}
			<span>Edit file</span>
		</Contextmenu_Entry>
		<Contextmenu_Entry
			run={() => {
				// TODO custom confirm dialog
				// eslint-disable-next-line no-alert
				if (confirm('Delete file "' + file.id + '"?')) {
					zzz.files.delete(file.id);
				}
			}}
		>
			{#snippet icon()}{GLYPH_REMOVE}{/snippet}
			<span>Delete file</span>
		</Contextmenu_Entry>
	{:else}
		<Contextmenu_Entry
			run={() => {
				update_view_with(view_with_prev);
			}}
		>
			{#snippet icon()}🗎{/snippet}
			<span>Close editor</span>
		</Contextmenu_Entry>
	{/if}

	<!-- TODO maybe show disabled? -->
	{#if file.contents !== null}
		<Contextmenu_Entry run={() => void navigator.clipboard.writeText(file.contents!)}>
			{#snippet icon()}📋{/snippet}
			<div class="flex">
				Copy {file.contents.length} chars
				<code class="size_sm ellipsis ml_sm">{file.contents.substring(0, 100)}</code>
			</div>
		</Contextmenu_Entry>
	{/if}

	<Contextmenu_Submenu>
		{#snippet icon()}>{/snippet}
		View file with
		{#snippet menu()}
			<!-- TODO `disabled` property to the entry -->
			<!-- TODO refactor into data with the types -->
			<Contextmenu_Entry run={() => update_view_with('summary')}>
				{#snippet icon()}{#if view_with === 'summary'}{'>'}{/if}{/snippet}
				<span>Summary</span>
			</Contextmenu_Entry>
			<Contextmenu_Entry run={() => update_view_with('info')}>
				{#snippet icon()}{#if view_with === 'info'}{'>'}{/if}{/snippet}
				<span>Info</span>
			</Contextmenu_Entry>
			<Contextmenu_Entry run={() => update_view_with('editor')}>
				{#snippet icon()}{#if view_with === 'editor'}{'>'}{/if}{/snippet}
				<span>Editor</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}
