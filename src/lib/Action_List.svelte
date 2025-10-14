<script lang="ts">
	// @slop Claude Opus 4
	// Action_List.svelte

	import type {SvelteHTMLElements} from 'svelte/elements';

	import {frontend_context} from '$lib/frontend.svelte.js';
	import type {Action} from '$lib/action.svelte.js';
	import Action_Listitem from '$lib/Action_Listitem.svelte';
	import Sortable_List from '$lib/Sortable_List.svelte';
	import {sort_by_numeric, sort_by_text} from '$lib/sortable.svelte.js';

	const {
		limit = 20,
		selected_action_id = null,
		attrs,
		onselect,
	}: {
		limit?: number | undefined;
		selected_action_id?: string | null | undefined;
		attrs?: SvelteHTMLElements['div'] | undefined;
		onselect?: ((action: Action) => void) | undefined;
	} = $props();

	const app = frontend_context.get();
	const {actions} = app;

	// Count total actions for the "showing X of Y" action
	const total_actions = $derived(actions.items.size);

	// TODO inefficient, query collection better probably
	const items = $derived(actions.items.values.slice(0, limit));
</script>

<div {...attrs} class="flex_1 unstyled overflow_auto scrollbar_width_thin {attrs?.class}">
	<!-- TODO @many more efficient array? maybe add `all` back to the base Indexed_Collection? -->
	<Sortable_List
		{items}
		sorters={[
			// TODO @many rework API to avoid casting
			sort_by_numeric<Action>('created_newest', 'newest first', 'created_date', 'desc'),
			sort_by_numeric<Action>('created_oldest', 'oldest first', 'created_date', 'asc'),
			sort_by_text<Action>('method_asc', 'method (a-z)', 'method'),
			sort_by_text<Action>('method_desc', 'method (z-a)', 'method', 'desc'),
		]}
		sort_key_default="created_newest"
		show_sort_controls={true}
		no_items=""
	>
		{#snippet children(action)}
			<Action_Listitem {action} selected={action.id === selected_action_id} {onselect} />
		{/snippet}
	</Sortable_List>

	{#if total_actions > limit}
		<div class="p_sm text_align_center">
			<small>Showing {limit} of {total_actions} actions</small>
		</div>
	{/if}
</div>
