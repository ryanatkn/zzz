<script lang="ts">
	import type {Source_File} from '@ryanatkn/gro/filer.js';
	import {slide} from 'svelte/transition';

	import Text_Icon from '$lib/Text_Icon.svelte';
	import {GLYPH_FILE} from '$lib/glyphs.js';
	import {to_root_path} from '$lib/path.js';

	interface Props {
		files: Map<string, Source_File>; // TODO BLOCK should be File right? need to remove Source_File from frontend state, replace
		selected_file_id?: string | null;
		onselect?: (file: Source_File) => void;
	}

	const {files, selected_file_id = null, onselect}: Props = $props();

	const sorted_files = $derived(
		Array.from(files.values()).sort((a, b) => to_root_path(a.id).localeCompare(to_root_path(b.id))),
	);

	const handle_select = (file: Source_File): void => {
		onselect?.(file);
	};

	// TODO BLOCK contextmenu to delete
</script>

<menu class="h_100 flex_1 unstyled overflow_y_auto">
	{#each sorted_files as file (file.id)}
		{@const selected = file.id === selected_file_id}
		<button
			type="button"
			class="file"
			class:selected
			class:sticky={selected}
			style:top={selected ? 0 : undefined}
			style:bottom={selected ? 0 : undefined}
			onclick={() => handle_select(file)}
			transition:slide
		>
			<div class="font_weight_400 flex align_items_center gap_xs">
				<Text_Icon icon={GLYPH_FILE} />
				<span class="word_break_break_all">{to_root_path(file.id)}</span>
			</div>
		</button>
	{:else}
		<p class="p_md text_align_center">No files available.</p>
	{/each}
</menu>

<style>
	button {
		justify-content: flex-start;
		width: 100%;
		text-align: left;
		padding: var(--space_xs2) var(--space_md);
		border-radius: 0;
		border: none;
		box-shadow: none;
	}
</style>
