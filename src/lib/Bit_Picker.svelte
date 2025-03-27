<script lang="ts">
	import Picker from '$lib/Picker.svelte';
	import Bit_Listitem from '$lib/Bit_Listitem.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Bit_Type} from '$lib/bit.svelte.js';
	import type {Uuid} from '$lib/zod_helpers.js';
	import {sort_by_text, sort_by_numeric} from '$lib/sortable.svelte.js';

	const zzz = zzz_context.get();
	const {bits} = zzz;

	interface Props {
		onpick: (bit: Bit_Type | undefined) => boolean | void;
		show?: boolean | undefined;
		filter?: ((bit: Bit_Type) => boolean) | undefined;
		exclude_ids?: Array<Uuid> | undefined;
	}

	let {show = $bindable(false), onpick, filter, exclude_ids}: Props = $props();
</script>

<Picker
	bind:show
	{onpick}
	items={bits.items}
	{filter}
	{exclude_ids}
	sorters={[
		// TODO @many why is the cast needed?
		sort_by_numeric('created_newest', 'newest first', 'created_date', 'desc'),
		sort_by_numeric('created_oldest', 'oldest first', 'created_date', 'asc'),
		sort_by_text<Bit_Type>('type_asc', 'type (a-z)', 'type'),
		sort_by_text<Bit_Type>('type_desc', 'type (z-a)', 'type', 'desc'),
		sort_by_text<Bit_Type>('name_asc', 'name (a-z)', 'name'),
		sort_by_text<Bit_Type>('name_desc', 'name (z-a)', 'name', 'desc'),
		sort_by_numeric<Bit_Type>('token_count_highest', 'tokens (most)', 'token_count', 'desc'),
		sort_by_numeric<Bit_Type>('token_count_lowest', 'tokens (least)', 'token_count', 'asc'),
	]}
	sort_key_default="created_newest"
	show_sort_controls
	heading="Pick a bit"
>
	{#snippet children(bit, pick)}
		<Bit_Listitem {bit} compact onclick={() => pick(bit)} />
	{/snippet}
</Picker>
