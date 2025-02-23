<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import type {Source_File} from '@ryanatkn/gro/filer.js';
	import {untrack} from 'svelte';
	import {slide} from 'svelte/transition';

	import {to_root_path} from '$lib/path.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';

	interface Props {
		file: Source_File;
		height?: number;
	}

	const {file, height = 600}: Props = $props();

	const {id} = $derived(file);

	const dependencies = $derived(Array.from(file.dependencies.values()));
	const dependents = $derived(Array.from(file.dependents.values()));

	const zzz = zzz_context.get();

	let contents_history: Array<{created: number; contents: string}> = $state([]);
	let updated_contents: string = $state(file.contents ?? '');
	let discarded_contents: string | null = $state(null);

	$effect.pre(() => {
		id; // When the file changes, reset the local state
		updated_contents = untrack(() => file.contents) ?? '';
		contents_history = [{created: Date.now(), contents: untrack(() => updated_contents)}];
	});
</script>

<div class="row size_lg word_break_break_all">
	<span class="size_xl3 mr_md">🗎</span>
	{to_root_path(file.id)}
</div>

<div class="row gap_md mb_sm">
	<Copy_To_Clipboard text={file.contents} />
	<div>{file.contents?.length} char{file.contents?.length === 1 ? '' : 's'}</div>
</div>

<div class="flex flex_wrap mb_sm">
	<div class="flex_1 width_md min_width_sm">
		<textarea style:height="{height}px" bind:value={updated_contents}></textarea>
	</div>
	<pre
		style:height="{height}px"
		class="flex_1 fg_1 radius_sm p_md width_md min_width_sm"
		style:min-width="var(--width_sm)">{file.contents}</pre>
</div>

<section class="flex justify_content_space_between width_xl">
	<button
		class="color_a"
		type="button"
		disabled={updated_contents === file.contents}
		onclick={() => {
			contents_history.push({created: Date.now(), contents: updated_contents});
			zzz.update_file(file.id, updated_contents);
			discarded_contents = null;
		}}>save file</button
	>
	<div class="flex gap_sm">
		<button
			type="button"
			disabled={updated_contents === file.contents}
			onclick={() => {
				discarded_contents = updated_contents;
				updated_contents = file.contents ?? '';
			}}>discard changes</button
		>
		<button
			type="button"
			disabled={discarded_contents === null}
			onclick={() => {
				if (discarded_contents !== null) {
					updated_contents = discarded_contents;
					discarded_contents = null;
				}
			}}>undo discard</button
		>
	</div>

	<Confirm_Button onclick={() => zzz.delete_file(file.id)} button_attrs={{class: 'color_c'}}>
		{#snippet children()}
			delete file
		{/snippet}
	</Confirm_Button>
</section>

{#if contents_history.length > 1 || contents_history[0].contents !== updated_contents}
	<div class="width_sm panel p_md" transition:slide>
		<h3 class="mt_0 mb_lg">history</h3>
		<menu class="unstyled flex flex_column_reverse">
			{#each contents_history as entry (entry)}
				<button
					type="button"
					class="justify_content_space_between"
					class:selected={entry.contents === updated_contents}
					onclick={() => {
						updated_contents = entry.contents;
						discarded_contents = null;
					}}
					transition:slide
				>
					<span>{new Date(entry.created).toLocaleTimeString()}</span>
					<span>{entry.contents.length} chars</span>
				</button>
			{/each}
		</menu>
	</div>
{/if}

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
