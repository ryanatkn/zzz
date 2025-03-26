<script lang="ts" generics="T extends {id: Uuid}">
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import {EMPTY_ARRAY} from '@ryanatkn/belt/array.js';
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import type {ComponentProps, Snippet} from 'svelte';

	import type {Uuid} from '$lib/zod_helpers.js';
	import type {Sorter} from '$lib/sortable.svelte.js';
	import type {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
	import Sortable_List from '$lib/Sortable_List.svelte';

	let {
		items,
		onpick,
		show = $bindable(false),
		dialog_props,
		children: children_prop,
		filter,
		exclude_ids,
		sorters = EMPTY_ARRAY,
		sort_key_default,
		show_sort_controls = false,
		no_items_message = 'No items available',
		heading = null,
	}: {
		/** The collection of items - required */
		items: Indexed_Collection<T>;
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
		no_items_message?: string | undefined;
		heading?: string | null | undefined;
		/** Called once per item */
		children: Snippet<[item: T, pick: (item: T) => void]>;
	} = $props();

	// Internal pick handler to manage show state
	const pick = (item: T): void => {
		// If onpick returns false explicitly, don't close the picker
		const should_close = onpick(item) !== false;
		if (should_close) {
			show = false;
		}
	};

	const cancel = (): void => {
		onpick(undefined);
		show = false;
	};
</script>

{#if show}
	<Dialog {...dialog_props} onclose={cancel}>
		<div class="pane p_lg">
			{#if heading}
				<h2 class="mt_lg text_align_center">{heading}</h2>
			{/if}

			<Sortable_List
				{items}
				{filter}
				{exclude_ids}
				{sorters}
				{sort_key_default}
				{show_sort_controls}
				{no_items_message}
			>
				{#snippet children(item)}
					{@render children_prop(item, pick)}
				{/snippet}
			</Sortable_List>
		</div>
	</Dialog>
{/if}
