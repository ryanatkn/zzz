<script lang="ts" generics="T extends {id: Uuid}">
	import type {Snippet} from 'svelte';
	import {EMPTY_ARRAY} from '@ryanatkn/belt/array.js';

	import type {Uuid} from '$lib/zod_helpers.js';
	import {Sortable, type Sorter} from '$lib/sortable.svelte.js';
	import type {Indexed_Collection} from '$lib/indexed_collection.svelte.js';

	const {
		items,
		filter,
		exclude_ids,
		sorters = EMPTY_ARRAY,
		sort_key_default,
		show_sort_controls = false,
		no_items_message = '[no items available]',
		children,
	}: {
		/** The collection of items */
		items: Indexed_Collection<T>;
		filter?: ((item: T) => boolean) | undefined;
		exclude_ids?: Array<Uuid> | undefined;
		sorters?: Array<Sorter<T>> | undefined;
		sort_key_default?: string | undefined;
		show_sort_controls?: boolean | undefined;
		no_items_message?: string | undefined;
		/** Called once per item */
		children: Snippet<[item: T]>;
	} = $props();

	const sortable = $state(
		new Sortable(
			() => items.all,
			() => sorters,
			() => sort_key_default,
		),
	);

	const filtered_items = $derived.by(() => {
		const all_items = items.all;

		// Quick return for common case (no filtering or sorting needed)
		if ((!exclude_ids || exclude_ids.length === 0) && !filter && !sortable.active_sort_fn) {
			return all_items;
		}

		let result = all_items;

		if (exclude_ids && exclude_ids.length > 0) {
			result = result.filter((item) => !exclude_ids.includes(item.id));
		}

		if (filter) {
			result = result.filter(filter);
		}

		if (sortable.active_sort_fn) {
			// If result is still the original array, we need to clone to avoid mutating the source
			if (result === all_items) {
				result = [...result];
			}
			result.sort(sortable.active_sort_fn);
		}

		return result;
	});
</script>

{#if show_sort_controls && sortable.sorters.length > 1}
	<div class="mb_md row gap_xs2">
		<small class="pr_xs3 white_space_nowrap">sort by</small>
		<menu class="unstyled flex flex_wrap justify_content_end gap_xs2">
			{#each sortable.sorters as sorter}
				<button
					type="button"
					class="compact font_weight_400"
					class:selected={sortable.active_key === sorter.key}
					onclick={() => sortable.set_sort(sorter.key)}
				>
					<div class="size_md">
						{sorter.label}
					</div>
				</button>
			{/each}
		</menu>
	</div>
{/if}

{#if filtered_items.length === 0}
	<div class="p_md">{no_items_message}</div>
{:else}
	<ul class="unstyled">
		{#each filtered_items as item (item.id)}
			<li>
				{@render children(item)}
			</li>
		{/each}
	</ul>
{/if}
