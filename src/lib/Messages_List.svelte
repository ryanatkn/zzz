<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {slide} from 'svelte/transition';

	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Message} from '$lib/message.svelte.js';
	import {get_icon_for_message_type, get_direction_icon} from '$lib/glyphs.js';

	interface Props {
		files?: Array<Message> | null;
		limit?: number;
		selected_message_id?: string | null;
		attrs?: SvelteHTMLElements['menu'];
		onselect?: (message: Message) => void;
	}

	const {files = null, limit = 20, selected_message_id = null, attrs, onselect}: Props = $props();

	const zzz = zzz_context.get();
	const messages = $derived(files ?? zzz.messages.items);

	const limited_messages = $derived(messages.slice(0, limit));

	const handle_select = (message: Message): void => {
		onselect?.(message);
	};

	// TODO BLOCK use component/class for the list (they'll be Nav_Links yeah?)
</script>

<menu {...attrs} class="flex_1 unstyled overflow_auto scrollbar_width_thin {attrs?.class}">
	{#each limited_messages as message (message.id)}
		{@const selected = message.id === selected_message_id}
		<button
			type="button"
			class="w_100 text_align_left justify_content_start py_xs px_md radius_0 border_none box_shadow_none"
			class:selected
			onclick={() => handle_select(message)}
			transition:slide
		>
			<div class="font_weight_400 flex align_items_center gap_xs w_100">
				<Glyph_Icon icon={get_icon_for_message_type(message.type)} />
				<Glyph_Icon icon={get_direction_icon(message.direction)} />
				<span class="font_mono flex_1">{message.type}</span>
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
	{:else}
		<p class="p_md text_align_center">No messages yet.</p>
	{/each}

	{#if messages.length > limit}
		<div class="p_sm text_align_center">
			<small>Showing {limit} of {messages.length} messages</small>
		</div>
	{/if}
</menu>

<style>
	.messages_list {
		width: 100%;
		max-height: 100%;
		overflow-y: auto;
		scrollbar-width: thin;
	}
</style>
