<script lang="ts">
	import Messages_List from '$lib/Messages_List.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {GLYPH_MESSAGE, GLYPH_PROMPT, GLYPH_RESPONSE} from '$lib/glyphs.js';
	import type {Message} from '$lib/message.svelte.js';
	import type {Send_Prompt_Message, Receive_Prompt_Message} from '$lib/message.svelte.js';
	import {to_completion_response_text} from '$lib/completion.js';

	let selected_message: Message | null = $state(null);

	const handle_select_message = (message: Message): void => {
		selected_message = message;
	};

	// Helper functions for type safety
	const is_send_prompt = (message: Message): boolean => {
		return message.type === 'send_prompt';
	};

	const is_completion_response = (message: Message): boolean => {
		return message.type === 'completion_response';
	};

	const get_prompt_data = (message: Message): Send_Prompt_Message['completion_request'] | null => {
		if (!is_send_prompt(message)) return null;

		const send_message = message.data as Send_Prompt_Message;
		return send_message.completion_request;
	};

	const get_completion_data = (
		message: Message,
	): Receive_Prompt_Message['completion_response'] | null => {
		if (!is_completion_response(message)) return null;

		const receive_message = message.data as Receive_Prompt_Message;
		return receive_message.completion_response;
	};

	const get_completion_text = (message: Message): string | null | undefined => {
		if (!is_completion_response(message)) return null;

		const response_data = get_completion_data(message);
		if (!response_data) return null;

		return to_completion_response_text(response_data);
	};
</script>

<div class="p_lg h_100">
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

		<div class="panel p_md overflow_y_auto h_100">
			{#if selected_message}
				<div class="mb_md">
					<h2 class="mt_0">
						{#if is_send_prompt(selected_message)}
							<Text_Icon icon={GLYPH_PROMPT} /> Prompt
						{:else if is_completion_response(selected_message)}
							<Text_Icon icon={GLYPH_RESPONSE} /> Response
						{:else}
							<Text_Icon icon={GLYPH_MESSAGE} /> {selected_message.type}
						{/if}
					</h2>
					<div class="flex flex_column gap_xs mt_sm color_text_subtle">
						<small class="font_mono">ID: {selected_message.id}</small>
						<small class="font_mono">Time: {selected_message.timestamp.toLocaleString()}</small>
						<small class="font_mono">Direction: {selected_message.direction}</small>
					</div>
				</div>

				<div>
					{#if selected_message.type === 'echo'}
						<pre
							class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm bg_alt rounded">{JSON.stringify(
								selected_message.data,
								null,
								2,
							)}</pre>
					{:else if is_send_prompt(selected_message)}
						{@const request_data = get_prompt_data(selected_message)}
						<div class="mb_lg">
							<h3>Prompt</h3>
							<pre
								class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm bg_alt rounded">{request_data?.prompt ||
									'No prompt'}</pre>

							<h3>Request Details</h3>
							<dl class="grid gap_xs gap_md_columns" style="grid-template-columns: 100px 1fr;">
								<dt class="font_weight_500">Model</dt>
								<dd>{request_data?.model || 'Unknown'}</dd>

								<dt class="font_weight_500">Provider</dt>
								<dd>{request_data?.provider_name || 'Unknown'}</dd>

								<dt class="font_weight_500">Created</dt>
								<dd>{request_data?.created || 'Unknown'}</dd>
							</dl>
						</div>
					{:else if is_completion_response(selected_message)}
						{@const response_data = get_completion_data(selected_message)}
						<div class="mb_lg">
							<h3>Completion</h3>
							<pre
								class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm bg_alt rounded">{get_completion_text(
									selected_message,
								) || 'No completion'}</pre>

							<h3>Response Details</h3>
							<dl class="grid gap_xs gap_md_columns" style="grid-template-columns: 100px 1fr;">
								<dt class="font_weight_500">Request ID</dt>
								<dd>{response_data?.request_id || 'Unknown'}</dd>

								<dt class="font_weight_500">Created</dt>
								<dd>{response_data?.created || 'Unknown'}</dd>
							</dl>
						</div>
					{:else}
						<pre
							class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm bg_alt rounded">{JSON.stringify(
								selected_message.data,
								null,
								2,
							)}</pre>
					{/if}
				</div>
			{:else}
				<div class="flex align_items_center justify_content_center h_100 color_text_subtle">
					<p>Select a message from the list to view its details</p>
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
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
</style>
