<script lang="ts">
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';
	import {slide} from 'svelte/transition';

	import Diskfile_Editor from '$lib/Diskfile_Editor.svelte';
	import Diskfile_Info from '$lib/Diskfile_Info.svelte';
	import Diskfile_Summary from '$lib/Diskfile_Summary.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';

	interface Props {
		file: Diskfile;
	}

	const {file}: Props = $props();

	// TODO refactor
	type Diskfile_View_Type = 'summary' | 'info' | 'editor';
	let view_with_prev: Diskfile_View_Type = $state('summary');
	let view_with: Diskfile_View_Type = $state('summary'); // TODO `selection` class pattern instead? `new Selection('summary')`

	const Diskfile_View_Component = $derived(
		view_with === 'summary'
			? Diskfile_Summary
			: view_with === 'info'
				? Diskfile_Info
				: Diskfile_Editor,
	);

	const update_view_with = (v: Diskfile_View_Type) => {
		view_with_prev = view_with;
		view_with = v;
	};

	const zzz = zzz_context.get();

	// TODO BLOCK show content in the right panel for the selected file
</script>

<div class="file_view" use:contextmenu_action={contextmenu_entries}>
	{#key Diskfile_View_Component}
		<div transition:slide>
			<Diskfile_View_Component {file} />
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
				if (confirm('Delete file "' + file.path + '"?')) {
					zzz.files.delete(file.path);
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
