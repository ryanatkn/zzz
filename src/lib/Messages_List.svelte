<script lang="ts">
	import {slide} from 'svelte/transition';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Message} from '$lib/message.svelte.js';
	import {get_icon_for_message_type, get_direction_icon} from '$lib/glyphs.js';

	interface Props {
		files?: Array<Message> | null;
		limit?: number;
		class_name?: string;
		selected_message_id?: string | null;
		onselect?: (message: Message) => void;
	}

	const {
		files = null,
		limit = 20,
		class_name = '',
		selected_message_id = null,
		onselect,
	}: Props = $props();

	const zzz = zzz_context.get();
	const messages = $derived(files ?? zzz.messages.items);

	const limited_messages = $derived(messages.slice(0, limit));

	const handle_select = (message: Message): void => {
		onselect?.(message);
	};

	// TODO BLOCK use component/class for the list (they'll be Nav_Links yeah?)
</script>

<menu class="flex_1 unstyled overflow_y_auto {class_name}">
	{#if limited_messages.length === 0}
		<p class="p_md text_align_center color_text_subtle">No messages yet.</p>
	{:else}
		{#each limited_messages as message (message.id)}
			{@const selected = message.id === selected_message_id}
			<button
				type="button"
				class="w_100 text_align_left justify_content_start py_xs px_md radius_0 border_none box_shadow_none"
				class:selected
				onclick={() => handle_select(message)}
				transition:slide
			>
				<div class="font_weight_400 flex align_items_center gap_xs">
					<Text_Icon icon={get_icon_for_message_type(message.type)} />
					<Text_Icon icon={get_direction_icon(message.direction)} />
					<span class="font_mono">{message.type}</span>
					<span class="font_mono size_sm ml_auto">{message.created_formatted_time}</span>
				</div>

				{#if selected && message.data}
					<div class="mt_xs">
						{#if message.is_prompt}
							<small class="mb_xs2 block">Prompt:</small>
							<pre
								class="font_mono size_xs white_space_pre_wrap word_break_break_word m_0 p_xs2 bg_alt rounded_xs">{message.prompt_preview}</pre>
						{:else if message.is_completion}
							<small class="mb_xs2 block">Response:</small>
							<pre
								class="font_mono size_xs white_space_pre_wrap word_break_break_word m_0 p_xs2 bg_alt rounded_xs">{message.completion_preview}</pre>
						{/if}
					</div>
				{/if}
			</button>
		{/each}

		{#if messages.length > limit}
			<div class="p_sm text_align_center color_text_subtle">
				<small>Showing {limit} of {messages.length} messages</small>
			</div>
		{/if}
	{/if}
</menu>

<style>
	.messages_list {
		width: 100%;
		max-height: 100%;
		overflow-y: auto;
	}
</style>
