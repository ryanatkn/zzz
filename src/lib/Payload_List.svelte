<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {slide} from 'svelte/transition';

	import Glyph from '$lib/Glyph.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Payload} from '$lib/payload.svelte.js';
	import {get_icon_for_payload_type, get_direction_icon} from '$lib/glyphs.js';
	import Sortable_List from '$lib/Sortable_List.svelte';
	import {sort_by_numeric, sort_by_text} from '$lib/sortable.svelte.js';

	interface Props {
		limit?: number | undefined;
		selected_payload_id?: string | null | undefined;
		attrs?: SvelteHTMLElements['menu'] | undefined;
		onselect?: ((payload: Payload) => void) | undefined;
	}

	const {limit = 20, selected_payload_id = null, attrs, onselect}: Props = $props();

	const zzz = zzz_context.get();
	const {payloads} = zzz;

	// Count total payloads for the "showing X of Y" payload
	const total_payloads = $derived(payloads.items.size);
</script>

<menu {...attrs} class="flex_1 unstyled overflow_auto scrollbar_width_thin {attrs?.class}">
	<!-- TODO @many more efficient array? maybe add `all` back to the base Indexed_Collection? -->
	<Sortable_List
		items={Array.from(payloads.items.by_id.values())}
		sorters={[
			// TODO @many why is the cast needed?
			sort_by_numeric<Payload>('created_newest', 'newest first', 'created_date', 'desc'),
			sort_by_numeric<Payload>('created_oldest', 'oldest first', 'created_date', 'asc'),
			sort_by_text<Payload>('type_asc', 'type (a-z)', 'type'),
			sort_by_text<Payload>('type_desc', 'type (z-a)', 'type', 'desc'),
		]}
		sort_key_default="created_newest"
		show_sort_controls={true}
		no_items_message="[no payloads yet]"
	>
		{#snippet children(payload)}
			{@const selected = payload.id === selected_payload_id}
			<button
				type="button"
				class="w_100 text_align_left justify_content_start py_xs px_md radius_0 border_none box_shadow_none"
				class:selected
				onclick={() => {
					onselect?.(payload);
				}}
				transition:slide
			>
				<div class="font_weight_400 flex align_items_center gap_xs w_100">
					<Glyph icon={get_icon_for_payload_type(payload.type)} />
					<Glyph icon={get_direction_icon(payload.direction)} />
					<span class="font_mono flex_1">{payload.type}</span>
					<small class="font_mono ml_auto">{payload.created_formatted_time}</small>
				</div>

				{#if selected && payload.data}
					<div class="mt_xs">
						{#if payload.is_prompt}
							<small class="mb_xs2 block">Prompt:</small>
							<pre
								class="font_mono size_xs white_space_pre_wrap word_break_break_word m_0 p_xs2">{payload.prompt_preview}</pre>
						{:else if payload.is_completion}
							<small class="mb_xs2 block">Response:</small>
							<pre
								class="font_mono size_xs white_space_pre_wrap word_break_break_word m_0 p_xs2">{payload.completion_preview}</pre>
						{/if}
					</div>
				{/if}
			</button>
		{/snippet}
	</Sortable_List>

	{#if total_payloads > limit}
		<div class="p_sm text_align_center">
			<small>Showing {limit} of {total_payloads} payloads</small>
		</div>
	{/if}
</menu>
