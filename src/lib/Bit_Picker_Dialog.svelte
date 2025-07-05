<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';

	import Picker_Dialog from '$lib/Picker_Dialog.svelte';
	import Bit_Listitem from '$lib/Bit_Listitem.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import type {Bit_Type} from '$lib/bit.svelte.js';
	import type {Uuid} from '$lib/zod_helpers.js';
	import {sort_by_text, sort_by_numeric} from '$lib/sortable.svelte.js';

	const app = frontend_context.get();
	const {bits} = app;

	interface Props {
		onpick: (bit: Bit_Type | undefined) => boolean | void;
		show?: boolean | undefined;
		filter?: ((bit: Bit_Type) => boolean) | undefined;
		exclude_ids?: Array<Uuid> | undefined;
		dialog_props?: Omit_Strict<ComponentProps<typeof Dialog>, 'children'> | undefined;
	}

	let {show = $bindable(false), onpick, filter, exclude_ids, dialog_props}: Props = $props();
</script>

<Picker_Dialog
	bind:show
	items={bits.items.values}
	{onpick}
	{filter}
	{exclude_ids}
	{dialog_props}
	sorters={[
		// TODO @many rework API to avoid casting
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
</Picker_Dialog>
