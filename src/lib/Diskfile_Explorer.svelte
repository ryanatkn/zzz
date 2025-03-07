<script lang="ts">
	import {slide} from 'svelte/transition';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Diskfile_List_Item from '$lib/Diskfile_List_Item.svelte';

	interface Props {
		onselect?: (file: Diskfile) => void;
	}

	const {onselect}: Props = $props();

	const zzz = zzz_context.get();
	const {diskfiles} = zzz;

	const sorted_files: Array<Diskfile> = $derived(
		[...diskfiles.non_external_files].sort((a, b) => {
			// Handle null/undefined path values
			if (!a.path && !b.path) return 0;
			if (!a.path) return 1; // null paths go last
			if (!b.path) return -1; // null paths go last

			return a.path.localeCompare(b.path);
		}),
	);

	// Handler for selecting a file, now using the diskfiles.select_file method
	const select_file = (file: Diskfile): void => {
		diskfiles.select_file(file.id);
		onselect?.(file);
	};
</script>

<div class="overflow_auto h_100">
	{#if sorted_files.length === 0}
		<div class="box h_100">No files available</div>
	{:else}
		<ul class="unstyled">
			{#each sorted_files as file (file.id)}
				<li transition:slide>
					<Diskfile_List_Item
						{file}
						selected={diskfiles.selected_file_id === file.id}
						onclick={select_file}
					/>
				</li>
			{/each}
		</ul>
	{/if}
</div>
