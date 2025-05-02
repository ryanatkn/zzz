<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {slide} from 'svelte/transition';

	import Glyph from '$lib/Glyph.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Action} from '$lib/action.svelte.js';
	import {get_icon_for_action_type, get_direction_icon} from '$lib/glyphs.js';
	import Sortable_List from '$lib/Sortable_List.svelte';
	import {sort_by_numeric, sort_by_text} from '$lib/sortable.svelte.js';

	interface Props {
		limit?: number | undefined;
		selected_action_id?: string | null | undefined;
		attrs?: SvelteHTMLElements['menu'] | undefined;
		onselect?: ((action: Action) => void) | undefined;
	}

	const {limit = 20, selected_action_id = null, attrs, onselect}: Props = $props();

	const zzz = zzz_context.get();
	const {actions} = zzz;

	// Count total actions for the "showing X of Y" action
	const total_actions = $derived(actions.items.size);
</script>

<menu {...attrs} class="flex_1 unstyled overflow_auto scrollbar_width_thin {attrs?.class}">
	<!-- TODO @many more efficient array? maybe add `all` back to the base Indexed_Collection? -->
	<Sortable_List
		items={Array.from(actions.items.by_id.values())}
		sorters={[
			// TODO @many rework API to avoid casting
			sort_by_numeric<Action>('created_newest', 'newest first', 'created_date', 'desc'),
			sort_by_numeric<Action>('created_oldest', 'oldest first', 'created_date', 'asc'),
			sort_by_text<Action>('type_asc', 'type (a-z)', 'type'),
			sort_by_text<Action>('type_desc', 'type (z-a)', 'type', 'desc'),
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
				onclick={() => {
					onselect?.(action);
				}}
				transition:slide
			>
				<div class="font_weight_400 flex align_items_center gap_xs w_100">
					<Glyph glyph={get_icon_for_action_type(action.type)} />
					<Glyph glyph={get_direction_icon(action.direction)} />
					<span class="font_mono flex_1">{action.type}</span>
					<small class="font_mono ml_auto">{action.created_formatted_time}</small>
				</div>

				{#if selected && action.data}
					<div class="mt_xs">
						{#if action.is_prompt}
							<small class="mb_xs2 block">Prompt:</small>
							<pre
								class="font_mono size_xs white_space_pre_wrap word_break_break_word m_0 p_xs2">{action.prompt_preview}</pre>
						{:else if action.is_completion}
							<small class="mb_xs2 block">Response:</small>
							<pre
								class="font_mono size_xs white_space_pre_wrap word_break_break_word m_0 p_xs2">{action.completion_preview}</pre>
						{/if}
					</div>
				{/if}
			</button>
		{/snippet}
	</Sortable_List>

	{#if total_actions > limit}
		<div class="p_sm text_align_center">
			<small>Showing {limit} of {total_actions} actions</small>
		</div>
	{/if}
</menu>
