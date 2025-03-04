<script lang="ts">
	import {slide} from 'svelte/transition';

	import Diskfile_View from '$lib/Diskfile_View.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Diskfile_List_Item from '$lib/Diskfile_List_Item.svelte';

	interface Props {
		onselect?: (file: Diskfile) => void;
	}

	const {onselect}: Props = $props();

	const zzz = zzz_context.get();

	let selected_file_id: string | null = $state(null);
	let selected_file: Diskfile | undefined = $derived(
		selected_file_id ? zzz.files.by_id.get(selected_file_id) : undefined,
	);

	const sorted_files: Array<Diskfile> = $derived(
		[...zzz.files.files].sort((a, b) => {
			// Handle null/undefined path values
			if (!a.path && !b.path) return 0;
			if (!a.path) return 1; // null paths go last
			if (!b.path) return -1; // null paths go last

			return a.path.localeCompare(b.path);
		}),
	);

	// Handler for selecting a file
	const select_file = (file: Diskfile): void => {
		selected_file_id = file.id;
		onselect?.(file);
	};
</script>

<div class="file_explorer">
	<div class="file_list panel">
		{#if sorted_files.length === 0}
			<div class="empty_state">No files available</div>
		{:else}
			<ul class="unstyled">
				{#each sorted_files as file (file.id)}
					<li transition:slide>
						<Diskfile_List_Item
							{file}
							selected={selected_file_id === file.id}
							onclick={select_file}
						/>
					</li>
				{/each}
			</ul>
		{/if}
	</div>

	<div class="file_details panel">
		{#if selected_file}
			<Diskfile_View file={selected_file} />
		{:else}
			<div class="empty_state">Select a file to view details</div>
		{/if}
	</div>
</div>

<style>
	.file_explorer {
		display: grid;
		grid-template-columns: 300px 1fr;
		gap: var(--space_md);
		height: 100%;
	}

	.file_list,
	.file_details {
		overflow: auto;
		height: 100%;
	}

	.empty_state {
		display: flex;
		justify-content: center;
		align-items: center;
		height: 100%;
		color: var(--color_text_subtle);
	}
</style>
