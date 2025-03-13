<script lang="ts">
	import {slide} from 'svelte/transition';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {page} from '$app/state';

	import {Uuid} from '$lib/zod_helpers.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Diskfile_List_Item from '$lib/Diskfile_List_Item.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {GLYPH_DIRECTORY} from '$lib/glyphs.js';

	interface Props {
		onselect?: (file: Diskfile) => void;
	}

	const {onselect}: Props = $props();

	const zzz = zzz_context.get();
	const {diskfiles} = zzz;

	// TODO add a select with name, name_reverse, created, created_reverse, updated, updated_reverse
	const sorted_files: Array<Diskfile> = $derived(
		[...diskfiles.non_external_files].sort((a, b) => {
			// Handle null/undefined path values
			if (!a.path && !b.path) return 0;
			if (!a.path) return 1; // null paths go last
			if (!b.path) return -1; // null paths go last

			return a.path.localeCompare(b.path);
		}),
	);

	// Handler for selecting a file that updates URL and internal state
	const select_file = (file: Diskfile): void => {
		// Update the URL with the file ID
		const url = new URL(window.location.href);
		url.searchParams.set('file', file.id);
		history.pushState({}, '', url);

		// Update internal state
		diskfiles.select_file(file.id);
		onselect?.(file);
	};

	// Sync URL parameter with selected file
	$effect(() => {
		const file_id_param = page.url.searchParams.get('file');
		if (!file_id_param) return;
		const parsed_uuid = Uuid.safeParse(file_id_param);
		if (parsed_uuid.success && diskfiles.by_id.has(parsed_uuid.data)) {
			diskfiles.select_file(parsed_uuid.data);
			const selected_file = sorted_files.find((file) => file.id === parsed_uuid.data);
			if (selected_file) {
				onselect?.(selected_file);
			}
		}
	});
</script>

<div class="h_100 overflow_auto scrollbar_width_thin">
	{#if zzz.zzz_dir === undefined}
		<div>&nbsp;</div>
	{:else if zzz.zzz_dir === null}
		<div><Pending_Animation /></div>
	{:else}
		<small class="block py_xs"><Glyph_Icon icon={GLYPH_DIRECTORY} /> {zzz.zzz_dir}</small>
		{#if sorted_files.length === 0}
			<div>No files available</div>
		{:else}
			<ul class="unstyled">
				{#each sorted_files as file (file.id)}
					{@const selected = diskfiles.selected_file_id === file.id}
					<li transition:slide class:selected>
						<Diskfile_List_Item {file} {selected} onclick={select_file} />
					</li>
				{/each}
			</ul>
		{/if}
	{/if}
</div>

<style>
	.selected {
		position: sticky;
		top: 0;
		bottom: 0;
		background-color: var(--bg); /* TODO needs to be opaque but this is a hack */
	}
</style>
