<script lang="ts">
	import Picker from '$lib/Picker.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import type {Uuid} from '$lib/zod_helpers.js';
	import {sort_by_text, sort_by_numeric} from '$lib/sortable.svelte.js';
	import Diskfile_Listitem from '$lib/Diskfile_Listitem.svelte';

	interface Props {
		onpick: (diskfile: Diskfile | undefined) => boolean | void;
		show?: boolean | undefined;
		filter?: ((diskfile: Diskfile) => boolean) | undefined;
		exclude_ids?: Array<Uuid> | undefined;
		selected_ids?: Array<Uuid> | undefined;
	}

	let {onpick, show = $bindable(false), filter, exclude_ids, selected_ids}: Props = $props();

	const zzz = zzz_context.get();
	const {diskfiles} = zzz;
</script>

<Picker
	bind:show
	{onpick}
	items={diskfiles.items}
	{filter}
	{exclude_ids}
	sorters={[
		sort_by_text<Diskfile>('path_asc', 'path (a-z)', 'path'),
		sort_by_text<Diskfile>('path_desc', 'path (z-a)', 'path', 'desc'),
		sort_by_numeric('created_newest', 'newest first', 'created_date', 'desc'),
		sort_by_numeric('created_oldest', 'oldest first', 'created_date', 'asc'),
		sort_by_numeric('updated_recently', 'recently updated', 'updated_date', 'desc'),
		sort_by_numeric('updated_oldest', 'least recently updated', 'updated_date', 'asc'),
		sort_by_numeric<Diskfile>('size_largest', 'largest first', 'content_length', 'desc'),
		sort_by_numeric<Diskfile>('size_smallest', 'smallest first', 'content_length', 'asc'),
	]}
	sort_key_default="path_asc"
	show_sort_controls
	heading="Pick a file"
>
	{#snippet children(diskfile, pick)}
		<Diskfile_Listitem
			{diskfile}
			selected={!!selected_ids && selected_ids.includes(diskfile.id)}
			onclick={pick}
		/>
	{/snippet}
</Picker>
