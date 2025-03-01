<script lang="ts">
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Message} from '$lib/message.svelte.js';

	interface Props {
		limit?: number;
		class_name?: string;
	}

	const {limit = 20, class_name = ''}: Props = $props();

	const zzz = zzz_context.get();
	const messages = $derived(zzz.messages);

	$derived.by(() => {
		limited_messages = messages.items.slice(0, limit);
		return limited_messages;
	});

	let limited_messages: Array<Message> = [];

	const formatTimestamp = (date: Date): string => {
		return date.toLocaleTimeString();
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
</script>

<div class="messages-list {class_name}">
	<h2><Text_Icon icon="📨" /> Messages ({messages.items.length})</h2>

	{#if messages.items.length === 0}
		<p>No messages yet.</p>
	{:else}
		<ul class="unstyled">
			{#each limited_messages as message (message.id)}
				<li class="message panel p_md mb_sm">
					<div class="row space_between">
						<div class="message-header">
							<Text_Icon icon={getIconForMessageType(message.type)} />
							<Text_Icon icon={getDirectionIcon(message.direction)} />
							<span class="font_mono">{message.type}</span>
						</div>
						<div class="message-time font_mono size_sm">
							{formatTimestamp(message.timestamp)}
						</div>
					</div>
					<div class="message-content mt_xs">
						{#if message.type === 'echo'}
							<pre class="message-data">{JSON.stringify(message.data, null, 2)}</pre>
						{:else if message.type === 'send_prompt'}
							<div class="message-prompt">
								<strong>Prompt:</strong>
								<pre>{(message.data as any).completion_request?.prompt || 'No prompt'}</pre>
							</div>
						{:else if message.type === 'completion_response'}
							<div class="message-response">
								<strong>Response:</strong>
								<pre>{(message.data as any).completion_response?.completion ||
										'No completion'}</pre>
							</div>
						{:else}
							<details>
								<summary>Message data</summary>
								<pre class="message-data">{JSON.stringify(message.data, null, 2)}</pre>
							</details>
						{/if}
					</div>
				</li>
			{/each}
		</ul>

		{#if messages.items.length > limit}
			<div class="text-center mt_md">
				<small>Showing {limit} of {messages.items.length} messages</small>
			</div>
		{/if}
	{/if}
</div>

<style>
	.messages-list {
		width: 100%;
	}

	.message {
		border-left: 3px solid var(--color_border);
	}

	.message-header {
		display: flex;
		align-items: center;
		gap: var(--space_xs);
	}

	.message-content {
		max-height: 300px;
		overflow-y: auto;
	}

	.message-data,
	.message-prompt pre,
	.message-response pre {
		font-family: var(--font_mono);
		font-size: var(--size_sm);
		white-space: pre-wrap;
		word-break: break-word;
		margin: var(--space_xs) 0;
		padding: var(--space_xs);
		background-color: var(--color_bg_alt);
		border-radius: var(--radius_sm);
	}

	.text-center {
		text-align: center;
	}
</style>
