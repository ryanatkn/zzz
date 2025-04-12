<script lang="ts" generics="T extends {id: Uuid}">
	import type {Snippet} from 'svelte';
	import {EMPTY_ARRAY} from '@ryanatkn/belt/array.js';
	import {slide} from 'svelte/transition';

	import type {Uuid} from '$lib/zod_helpers.js';
	import {Sortable, type Sorter} from '$lib/sortable.svelte.js';

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
		items: Array<T>;
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
			() => items,
			() => sorters,
			() => sort_key_default,
		),
	);

	const filtered_items = $derived.by(() => {
		// Quick return for common case (no filtering or sorting needed)
		if ((!exclude_ids || exclude_ids.length === 0) && !filter && !sortable.active_sort_fn) {
			return items;
		}

		let result = items;

		if (exclude_ids && exclude_ids.length > 0) {
			result = result.filter((item) => !exclude_ids.includes(item.id));
		}

		if (filter) {
			result = result.filter(filter);
		}

		if (sortable.active_sort_fn) {
			// If result is still the original array, clone to avoid mutating the source
			if (result === items) {
				result = [...result];
			}
			result.sort(sortable.active_sort_fn);
		}

		return result;
	});
</script>

{#if show_sort_controls && sortable.sorters.length > 1}
	<label class="p_sm row gap_xs2 mb_0" transition:slide>
		<small class="pr_xs3 white_space_nowrap">sort by</small>
		<select bind:value={sortable.active_key} class="compact plain size_sm">
			{#each sortable.sorters as sorter (sorter.key)}
				<option value={sorter.key}>
					{sorter.label}
				</option>
			{/each}
		</select>
	</label>
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
