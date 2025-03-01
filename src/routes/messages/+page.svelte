<script lang="ts">
	import Messages_List from '$lib/Messages_List.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {GLYPH_MESSAGE} from '$lib/glyphs.js';
	import type {Message} from '$lib/message.svelte.js';

	let selected_message: Message | null = $state(null);

	const handle_select_message = (message: Message): void => {
		selected_message = message;
	};
</script>

<div class="messages-page p_lg">
	<h1><Text_Icon icon={GLYPH_MESSAGE} /> messages</h1>
	<p>System messages between client and server.</p>

	<div class="messages-container mt_md">
		<div class="messages-sidebar">
			<Messages_List
				limit={100}
				selected_message_id={selected_message?.id}
				onselect={handle_select_message}
			/>
		</div>

		<div class="messages-detail panel p_md">
			{#if selected_message}
				<div class="message-header mb_md">
					<h2 class="message-title">
						{#if selected_message.type === 'send_prompt'}
							<Text_Icon icon="❓" /> Prompt
						{:else if selected_message.type === 'completion_response'}
							<Text_Icon icon="💬" /> Response
						{:else}
							<Text_Icon icon={GLYPH_MESSAGE} /> {selected_message.type}
						{/if}
					</h2>
					<div class="message-meta">
						<small class="font_mono">ID: {selected_message.id}</small>
						<small class="font_mono">Time: {selected_message.timestamp.toLocaleString()}</small>
						<small class="font_mono">Direction: {selected_message.direction}</small>
					</div>
				</div>

				<div class="message-content">
					{#if selected_message.type === 'echo'}
						<pre class="message-data">{JSON.stringify(selected_message.data, null, 2)}</pre>
					{:else if selected_message.type === 'send_prompt'}
						<div class="message-section">
							<h3>Prompt</h3>
							<pre class="message-data">{selected_message.data.completion_request?.prompt ||
									'No prompt'}</pre>

							<h3>Request Details</h3>
							<dl class="message-details">
								<dt>Model</dt>
								<dd>{selected_message.data.completion_request?.model || 'Unknown'}</dd>

								<dt>Provider</dt>
								<dd>
									{selected_message.data.completion_request?.provider_name || 'Unknown'}
								</dd>

								<dt>Created</dt>
								<dd>{selected_message.data.completion_request?.created || 'Unknown'}</dd>
							</dl>
						</div>
					{:else if selected_message.type === 'completion_response'}
						<div class="message-section">
							<h3>Completion</h3>
							<pre class="message-data">{selected_message.data.completion_response?.completion ||
									'No completion'}</pre>

							<h3>Response Details</h3>
							<dl class="message-details">
								<dt>Request ID</dt>
								<dd>
									{selected_message.data.completion_response?.request_id || 'Unknown'}
								</dd>

								<dt>Created</dt>
								<dd>{selected_message.data.completion_response?.created || 'Unknown'}</dd>
							</dl>
						</div>
					{:else}
						<pre class="message-data">{JSON.stringify(selected_message.data, null, 2)}</pre>
					{/if}
				</div>
			{:else}
				<div class="message-empty-state">
					<!-- TODO maybe show some useful default info/content here? it's like the root/home state -->
					<p>Select a message from the list to view its details</p>
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
	.messages-page {
		height: 100%;
	}

	.messages-container {
		display: grid;
		grid-template-columns: 320px 1fr;
		gap: var(--space_md);
		height: calc(100vh - 200px);
	}

	.messages-sidebar {
		overflow-y: auto;
		border-right: 1px solid var(--color_border);
	}

	.messages-detail {
		overflow-y: auto;
		height: 100%;
	}

	.message-title {
		margin-top: 0;
	}

	.message-meta {
		display: flex;
		flex-direction: column;
		gap: var(--space_xs);
		margin-top: var(--space_sm);
		color: var(--color_text_subtle);
	}

	.message-data {
		font-family: var(--font_mono);
		font-size: var(--size_sm);
		white-space: pre-wrap;
		word-break: break-word;
		padding: var(--space_sm);
		background-color: var(--color_bg_alt);
		border-radius: var(--radius_sm);
		overflow-x: auto;
	}

	.message-section {
		margin-bottom: var(--space_lg);
	}

	.message-details {
		display: grid;
		grid-template-columns: 100px 1fr;
		gap: var(--space_xs) var(--space_md);
	}

	.message-details dt {
		font-weight: 500;
	}

	.message-empty-state {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
		color: var(--color_text_subtle);
	}
</style>
