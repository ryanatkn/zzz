<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {slide} from 'svelte/transition';

	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Message} from '$lib/message.svelte.js';
	import {get_icon_for_message_type, get_direction_icon} from '$lib/glyphs.js';
	import Sortable_List from '$lib/Sortable_List.svelte';
	import {sort_by_numeric, sort_by_text} from '$lib/sortable.svelte.js';

	interface Props {
		limit?: number | undefined;
		selected_message_id?: string | null | undefined;
		attrs?: SvelteHTMLElements['menu'] | undefined;
		onselect?: ((message: Message) => void) | undefined;
	}

	const {limit = 20, selected_message_id = null, attrs, onselect}: Props = $props();

	const zzz = zzz_context.get();
	const {messages} = zzz;

	// Count total messages for the "showing X of Y" message
	const total_messages = $derived(messages.items.all.length);
</script>

<menu {...attrs} class="flex_1 unstyled overflow_auto scrollbar_width_thin {attrs?.class}">
	<Sortable_List
		items={messages.items}
		filter={(message) => {
			// Limit filter for messages - show only the first N messages by created date (newest first)

			// Get the first N items
			const limited = messages.items.all.slice(0, limit);

			// Check if the current message is in the limited set
			return limited.some((item) => item.id === message.id);
		}}
		sorters={[
			// TODO @many why is the cast needed?
			sort_by_numeric<Message>('created_newest', 'newest first', 'created_date', 'desc'),
			sort_by_numeric<Message>('created_oldest', 'oldest first', 'created_date', 'asc'),
			sort_by_text<Message>('type_asc', 'type (a-z)', 'type'),
			sort_by_text<Message>('type_desc', 'type (z-a)', 'type', 'desc'),
		]}
		sort_key_default="created_newest"
		show_sort_controls={true}
		no_items_message="[no messages yet]"
	>
		{#snippet children(message)}
			{@const selected = message.id === selected_message_id}
			<button
				type="button"
				class="w_100 text_align_left justify_content_start py_xs px_md radius_0 border_none box_shadow_none"
				class:selected
				onclick={() => {
					onselect?.(message);
				}}
				transition:slide
			>
				<div class="font_weight_400 flex align_items_center gap_xs w_100">
					<Glyph_Icon icon={get_icon_for_message_type(message.type)} />
					<Glyph_Icon icon={get_direction_icon(message.direction)} />
					<span class="font_mono flex_1">{message.type}</span>
					<small class="font_mono ml_auto">{message.created_formatted_time}</small>
				</div>

				{#if selected && message.data}
					<div class="mt_xs">
						{#if message.is_prompt}
							<small class="mb_xs2 block">Prompt:</small>
							<pre
								class="font_mono size_xs white_space_pre_wrap word_break_break_word m_0 p_xs2">{message.prompt_preview}</pre>
						{:else if message.is_completion}
							<small class="mb_xs2 block">Response:</small>
							<pre
								class="font_mono size_xs white_space_pre_wrap word_break_break_word m_0 p_xs2">{message.completion_preview}</pre>
						{/if}
					</div>
				{/if}
			</button>
		{/snippet}
	</Sortable_List>

	{#if total_messages > limit}
		<div class="p_sm text_align_center">
			<small>Showing {limit} of {total_messages} messages</small>
		</div>
	{/if}
</menu>

<style>
	.messages_list {
		width: 100%;
		max-height: 100%;
		overflow: auto;
		scrollbar-width: thin;
	}
</style>
