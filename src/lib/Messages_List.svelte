<script lang="ts">
	import {slide} from 'svelte/transition';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Message} from '$lib/message.svelte.js';
	import {get_icon_for_message_type, get_direction_icon} from '$lib/glyphs.js';

	interface Props {
		limit?: number;
		class_name?: string;
		selected_message_id?: string | null;
		onselect?: (message: Message) => void;
	}

	const {limit = 20, class_name = '', selected_message_id = null, onselect}: Props = $props();

	const zzz = zzz_context.get();
	const messages = $derived(zzz.messages);

	const limited_messages: Array<Message> = $derived(messages.items.slice(0, limit));

	const handle_select = (message: Message): void => {
		onselect?.(message);
	};

	// TODO BLOCK use component/class for the list (they'll be Nav_Links yeah?)
</script>

<div class="messages-list {class_name}">
	{#if messages.items.length === 0}
		<p class="empty-state">No messages yet.</p>
	{:else}
		<menu class="flex_1 unstyled">
			{#each limited_messages as message (message.id)}
				{@const selected = message.id === selected_message_id}
				<button
					type="button"
					class="message-item"
					class:selected
					class:sticky={selected}
					style:top={selected ? 0 : undefined}
					style:bottom={selected ? 0 : undefined}
					onclick={() => handle_select(message)}
					transition:slide
				>
					<div class="message-header font_weight_400">
						<Text_Icon icon={get_icon_for_message_type(message.type)} />
						<Text_Icon icon={get_direction_icon(message.direction)} />
						<span class="message-type font_mono">{message.type}</span>
						<span class="message-time font_mono size_sm">{message.created_formatted_time}</span>
					</div>

					{#if selected && message.data}
						<div class="message-preview mt_xs">
							{#if message.is_prompt}
								<small class="message-preview-label">Prompt:</small>
								<pre class="message-preview-content">{message.prompt_preview}</pre>
							{:else if message.is_completion}
								<small class="message-preview-label">Response:</small>
								<pre class="message-preview-content">{message.completion_preview}</pre>
							{/if}
						</div>
					{/if}
				</button>
			{/each}
		</menu>

		{#if messages.items.length > limit}
			<div class="text_align_center mt_md">
				<small>Showing {limit} of {messages.items.length} messages</small>
			</div>
		{/if}
	{/if}
</div>

<style>
	.messages-list {
		width: 100%;
		max-height: 100%;
		overflow-y: auto;
	}

	.empty-state {
		padding: var(--space_md);
		color: var(--color_text_subtle);
		text-align: center;
	}

	.message-item {
		justify-content: flex-start;
		width: 100%;
		text-align: left;
		padding: var(--space_xs) var(--space_md);
		border-radius: 0;
		border: none;
		box-shadow: none;
		border-left: 3px solid transparent;
	}

	.message-item:hover {
		background-color: var(--fg_1);
	}
	.message-item:active {
		background-color: var(--fg_2);
	}
	.message-item.selected {
		background-color: var(--fg_3);
	}

	.message-header {
		display: flex;
		align-items: center;
		gap: var(--space_xs);
	}

	.message-time {
		margin-left: auto;
	}

	.message-type {
		color: var(--color_text);
	}

	.message-preview {
		max-height: 50px;
		overflow: hidden;
	}

	.message-preview-label {
		margin-bottom: var(--space_xs2);
		display: block;
	}

	.message-preview-content {
		font-family: var(--font_mono);
		font-size: var(--size_xs);
		white-space: pre-wrap;
		word-break: break-word;
		margin: 0;
		padding: var(--space_xs2);
		background-color: var(--color_bg_alt);
		border-radius: var(--radius_xs);
	}
</style>
