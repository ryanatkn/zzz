<script lang="ts">
	import Picker from '$lib/Picker.svelte';
	import PartListitem from '$lib/PartListitem.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import type {PartUnion} from '$lib/part.svelte.js';
	import type {Uuid} from '$lib/zod_helpers.js';
	import {sort_by_text, sort_by_numeric} from '$lib/sortable.svelte.js';

	const app = frontend_context.get();
	const {parts} = app;

	const {
		onpick,
		filter,
		exclude_ids,
	}: {
		onpick: (part: PartUnion | undefined) => boolean | void;
		filter?: ((part: PartUnion) => boolean) | undefined;
		exclude_ids?: Array<Uuid> | undefined;
	} = $props();
</script>

<Picker
	items={parts.items.values}
	{onpick}
	{filter}
	{exclude_ids}
	sorters={[
		// TODO @many rework API to avoid casting
		sort_by_numeric('created_newest', 'newest first', 'created_date', 'desc'),
		sort_by_numeric('created_oldest', 'oldest first', 'created_date', 'asc'),
		sort_by_text<PartUnion>('type_asc', 'type (a-z)', 'type'),
		sort_by_text<PartUnion>('type_desc', 'type (z-a)', 'type', 'desc'),
		sort_by_text<PartUnion>('name_asc', 'name (a-z)', 'name'),
		sort_by_text<PartUnion>('name_desc', 'name (z-a)', 'name', 'desc'),
		sort_by_numeric<PartUnion>('token_count_highest', 'tokens (most)', 'token_count', 'desc'),
		sort_by_numeric<PartUnion>('token_count_lowest', 'tokens (least)', 'token_count', 'asc'),
	]}
	sort_key_default="created_newest"
	show_sort_controls
	heading="Pick a part"
>
	{#snippet children(part, pick)}
		<PartListitem {part} compact onclick={() => pick(part)} />
	{/snippet}
</Picker>
