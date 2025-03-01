<script lang="ts">
	import Messages_List from '$lib/Messages_List.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {GLYPH_MESSAGE, GLYPH_PROMPT, GLYPH_RESPONSE} from '$lib/glyphs.js';
	import type {Message} from '$lib/message.svelte.js';

	let selected_message: Message | null = $state(null);

	const handle_select_message = (message: Message): void => {
		selected_message = message;
	};
</script>

<div class="p_lg h_100">
	<h1><Text_Icon icon={GLYPH_MESSAGE} /> messages</h1>
	<p>System messages between client and server.</p>

	<div class="messages_container mt_md">
		<div class="messages_sidebar">
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
						{#if selected_message.is_prompt}
							<Text_Icon icon={GLYPH_PROMPT} /> Prompt
						{:else if selected_message.is_completion}
							<Text_Icon icon={GLYPH_RESPONSE} /> Response
						{:else}
							<Text_Icon icon={GLYPH_MESSAGE} /> {selected_message.type}
						{/if}
					</h2>
					<div class="flex flex_column gap_xs mt_sm color_text_subtle">
						<small class="font_mono">ID: {selected_message.id}</small>
						<small class="font_mono">
							Time: {selected_message.created_formatted_date}
						</small>
						<small class="font_mono">Direction: {selected_message.direction}</small>
					</div>
				</div>

				<div>
					{#if selected_message.is_echo}
						<pre
							class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm bg_alt rounded">{JSON.stringify(
								selected_message.data,
								null,
								2,
							)}</pre>
					{:else if selected_message.is_prompt}
						<div class="mb_lg">
							<h3>Prompt</h3>
							<pre
								class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm bg_alt rounded">{selected_message
									.prompt_data?.prompt || 'No prompt'}</pre>

							<h3>Request Details</h3>
							<dl class="grid gap_xs gap_md_columns" style="grid-template-columns: 100px 1fr;">
								<dt class="font_weight_500">Model</dt>
								<dd>{selected_message.prompt_data?.model || 'Unknown'}</dd>

								<dt class="font_weight_500">Provider</dt>
								<dd>{selected_message.prompt_data?.provider_name || 'Unknown'}</dd>

								<dt class="font_weight_500">Created</dt>
								<dd>{selected_message.prompt_data?.created || 'Unknown'}</dd>
							</dl>
						</div>
					{:else if selected_message.is_completion}
						<div class="mb_lg">
							<h3>Completion</h3>
							<pre
								class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm bg_alt rounded">{selected_message.completion_text ||
									'No completion'}</pre>

							<h3>Response Details</h3>
							<dl class="grid gap_xs gap_md_columns" style="grid-template-columns: 100px 1fr;">
								<dt class="font_weight_500">Request ID</dt>
								<dd>{selected_message.completion_data?.request_id || 'Unknown'}</dd>

								<dt class="font_weight_500">Created</dt>
								<dd>{selected_message.completion_data?.created || 'Unknown'}</dd>
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
	.messages_container {
		display: grid;
		grid-template-columns: 320px 1fr;
		gap: var(--space_md);
		height: calc(100vh - 200px);
	}

	.messages_sidebar {
		overflow-y: auto;
		border-right: 1px solid var(--color_border);
	}
</style>
