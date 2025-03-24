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
		default_sort_key,
		show_sort_controls = false,
		no_items_message = '[no items available]',
		children,
	}: {
		/** The collection of items */
		items: Indexed_Collection<T>;
		filter?: ((item: T) => boolean) | undefined;
		exclude_ids?: Array<Uuid> | undefined;
		sorters?: Array<Sorter<T>> | undefined;
		default_sort_key?: string | undefined;
		show_sort_controls?: boolean | undefined;
		no_items_message?: string | undefined;
		/** Called once per item */
		children: Snippet<[item: T]>;
	} = $props();

	const sortable = $state(
		new Sortable(
			() => items.all,
			() => sorters,
			() => default_sort_key,
		),
	);

	// Common filtering logic
	const filtered_items = $derived.by(() => {
		let result = [...items.all];

		// Apply id exclusion if specified
		if (exclude_ids && exclude_ids.length > 0) {
			result = result.filter((item) => !exclude_ids.includes(item.id));
		}

		// Apply custom filter if provided
		if (filter) {
			result = result.filter(filter);
		}

		// Apply sorting using sortable if available
		if (sortable.active_sort_fn) {
			result = result.sort(sortable.active_sort_fn);
		}

		return result;
	});
</script>

{#if show_sort_controls && sortable.sorters.length > 1}
	<div class="mb_md row flex_wrap gap_xs2">
		<div>sort by</div>
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
