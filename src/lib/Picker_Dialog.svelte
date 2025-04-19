<script lang="ts" generics="T extends {id: Uuid}">
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import type {ComponentProps, Snippet} from 'svelte';

	import type {Uuid} from '$lib/zod_helpers.js';
	import type {Sorter} from '$lib/sortable.svelte.js';
	import Picker from '$lib/Picker.svelte';

	let {
		items,
		onpick,
		show = $bindable(false),
		dialog_props,
		children: children_prop,
		filter,
		exclude_ids,
		sorters,
		sort_key_default,
		show_sort_controls,
		no_items,
		heading,
	}: {
		/** The collection of items to be picked from. */
		items: Array<T>;
		/**
		 * Handle both picking an item or no item.
		 * Return `false` to prevent closing.
		 */
		onpick: (item: T | undefined) => boolean | void;
		show?: boolean | undefined;
		dialog_props?: Omit_Strict<ComponentProps<typeof Dialog>, 'children'> | undefined;
		filter?: ((item: T) => boolean) | undefined;
		exclude_ids?: Array<Uuid> | undefined;
		sorters?: Array<Sorter<T>> | undefined;
		sort_key_default?: string | undefined;
		show_sort_controls?: boolean | undefined;
		no_items?: Snippet | string | undefined;
		heading?: string | null | undefined;
		/** Called once per item */
		children: Snippet<[item: T, pick: (item: T) => void]>;
	} = $props();
</script>

{#if show}
	<Dialog
		{...dialog_props}
		onclose={() => {
			onpick(undefined);
			show = false;
		}}
	>
		<div class="pane p_lg width_md mx_auto">
			<Picker
				{items}
				{filter}
				{exclude_ids}
				{sorters}
				{sort_key_default}
				{show_sort_controls}
				{no_items}
				{heading}
				onpick={(item) => {
					// If onpick returns false explicitly, don't close the picker
					const should_close = onpick(item) !== false;
					if (should_close) {
						show = false;
					}
				}}
			>
				{#snippet children(item, inner_pick)}
					{@render children_prop(item, inner_pick)}
				{/snippet}
			</Picker>
		</div>
	</Dialog>
{/if}
