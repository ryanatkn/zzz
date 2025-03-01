<script lang="ts">
	import {slide} from 'svelte/transition';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Message} from '$lib/message.svelte.js';

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

	const getIconForMessageType = (type: string): string => {
		switch (type) {
			case 'echo':
				return '🔄';
			case 'send_prompt':
				return '❓';
			case 'completion_response':
				return '💬';
			case 'load_session':
				return '📂';
			case 'loaded_session':
				return '📁';
			case 'update_file':
				return '✏️';
			case 'delete_file':
				return '🗑️';
			case 'filer_change':
				return '📝';
			default:
				return '📨';
		}
	};

	const getDirectionIcon = (direction: string): string => {
		switch (direction) {
			case 'client':
				return '↗️';
			case 'server':
				return '↘️';
			case 'both':
				return '↔️';
			default:
				return '❓';
		}
	};

	const formatTimestamp = (date: Date): string => {
		return date.toLocaleTimeString();
	};
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
						<Text_Icon icon={getIconForMessageType(message.type)} />
						<Text_Icon icon={getDirectionIcon(message.direction)} />
						<span class="message-type font_mono">{message.type}</span>
						<span class="message-time font_mono size_sm">{formatTimestamp(message.timestamp)}</span>
					</div>

					{#if selected && message.data}
						<div class="message-preview mt_xs">
							{#if message.type === 'send_prompt'}
								<small class="message-preview-label">Prompt:</small>
								<pre class="message-preview-content">{(
										message.data as any
									).completion_request?.prompt.substring(0, 50) + '...' || 'No prompt'}</pre>
							{:else if message.type === 'completion_response'}
								<small class="message-preview-label">Response:</small>
								<pre class="message-preview-content">{(
										message.data as any
									).completion_response?.completion.substring(0, 50) + '...' ||
										'No completion'}</pre>
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
		background-color: var(--color_bg_hover);
	}

	.message-header {
		display: flex;
		align-items: center;
		gap: var(--space_xs);
	}

	.message-time {
		margin-left: auto;
		color: var(--color_text_subtle);
	}

	.message-type {
		color: var(--color_text);
	}

	.message-preview {
		max-height: 50px;
		overflow: hidden;
	}

	.message-preview-label {
		color: var(--color_text_subtle);
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
