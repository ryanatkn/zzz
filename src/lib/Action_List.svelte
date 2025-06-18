<script lang="ts">
	// @slop claude_opus_4
	// Action_List.svelte

	import type {SvelteHTMLElements} from 'svelte/elements';
	import {slide} from 'svelte/transition';

	import Glyph from '$lib/Glyph.svelte';
	import {zzz_context} from '$lib/frontend.svelte.js';
	import type {Action} from '$lib/action.svelte.js';
	import {get_glyph_for_action_method, get_glyph_for_action_kind} from '$lib/glyphs.js';
	import Sortable_List from '$lib/Sortable_List.svelte';
	import {sort_by_numeric, sort_by_text} from '$lib/sortable.svelte.js';

	interface Props {
		limit?: number | undefined;
		selected_action_id?: string | null | undefined;
		attrs?: SvelteHTMLElements['menu'] | undefined;
		onselect?: ((action: Action) => void) | undefined;
	}

	const {limit = 20, selected_action_id = null, attrs, onselect}: Props = $props();

	const app = zzz_context.get();
	const {actions} = app;

	// Count total actions for the "showing X of Y" action
	const total_actions = $derived(actions.items.size);

	// TODO inefficient, query collection better probably
	const items = $derived(Array.from(actions.items.by_id.values()).slice(0, limit));
</script>

<menu {...attrs} class="flex_1 unstyled overflow_auto scrollbar_width_thin {attrs?.class}">
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
		no_items="[no actions yet]"
	>
		{#snippet children(action)}
			{@const selected = action.id === selected_action_id}
			<button
				type="button"
				class="w_100 text_align_left justify_content_start py_xs px_md border_radius_0 border_style_none box_shadow_none"
				class:selected
				class:color_c={action.has_error}
				onclick={() => {
					onselect?.(action);
				}}
				transition:slide
			>
				<div class="font_weight_400 display_flex align_items_center gap_xs w_100">
					<Glyph glyph={get_glyph_for_action_method(action.method)} />
					<Glyph glyph={get_glyph_for_action_kind(action.kind)} />
					<span class="font_family_mono flex_1">{action.method}</span>
					{#if action.has_error}
						<small class="color_c">!</small>
					{/if}
					<small class="font_family_mono ml_auto">{action.created_formatted_time}</small>
				</div>
			</button>
		{/snippet}
	</Sortable_List>

	{#if total_actions > limit}
		<div class="p_sm text_align_center">
			<small>Showing {limit} of {total_actions} actions</small>
		</div>
	{/if}
</menu>
