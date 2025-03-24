<script lang="ts">
	import Picker from '$lib/Picker.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Diskfile_List_Item from '$lib/Diskfile_List_Item.svelte';
	import type {Uuid} from '$lib/zod_helpers.js';

	interface Props {
		onpick: (diskfile: Diskfile | null | undefined) => boolean | void;
		show?: boolean | undefined;
		filter?: ((diskfile: Diskfile) => boolean) | undefined;
		exclude_ids?: Array<Uuid> | undefined;
		selected_ids?: Array<Uuid> | undefined;
	}

	let {onpick, show = $bindable(false), filter, exclude_ids, selected_ids}: Props = $props();

	const zzz = zzz_context.get();
	const {diskfiles} = zzz;

	// TODO refactor
	const filtered_diskfiles = $derived(
		diskfiles.non_external_diskfiles
			.filter((diskfile) => {
				// Check if the file ID is in the exclude list
				if (exclude_ids?.includes(diskfile.id)) {
					return false;
				}
				// Apply the custom filter if provided
				return filter ? filter(diskfile) : true;
			})
			.sort((a, b) => {
				if (!a.path && !b.path) return 0;
				if (!a.path) return 1;
				if (!b.path) return -1;
				return a.path.localeCompare(b.path);
			}),
	);
</script>

<Picker bind:show {onpick}>
	{#snippet children(pick)}
		<h2 class="mt_lg text_align_center">Pick a file</h2>
		{#if filtered_diskfiles.length === 0}
			<div class="p_md">No files available</div>
		{:else}
			<div class="row gap_sm">
				<button type="button" onclick={() => pick(null)} class="mb_lg">pick no file</button>
				<button type="button" onclick={() => pick(undefined)} class="mb_lg">cancel</button>
			</div>
			<ul class="unstyled">
				{#each filtered_diskfiles as diskfile (diskfile.id)}
					<li>
						<Diskfile_List_Item
							{diskfile}
							selected={!!selected_ids && selected_ids.includes(diskfile.id)}
							onclick={() => pick(diskfile)}
						/>
					</li>
				{/each}
			</ul>
		{/if}
	{/snippet}
</Picker>
