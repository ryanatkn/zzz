<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';

	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {GLYPH_PROMPT, GLYPH_RESPONSE, GLYPH_FILE, GLYPH_MESSAGE} from '$lib/glyphs.js';
	import type {Message} from '$lib/message.svelte.js';

	interface Props {
		message: Message;
	}

	const {message}: Props = $props();
</script>

<div class="mb_md">
	<div class="size_lg">
		{#if message.is_prompt}
			<Glyph_Icon icon={GLYPH_PROMPT} /> Prompt
		{:else if message.is_completion}
			<Glyph_Icon icon={GLYPH_RESPONSE} /> Response
		{:else if message.is_file_related}
			<Glyph_Icon icon={GLYPH_FILE} /> File {message.type}
		{:else}
			<Glyph_Icon icon={GLYPH_MESSAGE} /> {message.type}
		{/if}
		<span class="size_sm color_subtle ml_xs">{message.direction}</span>
	</div>
	<div class="flex flex_column gap_xs mt_sm">
		<small class="font_mono">ID: {message.id}</small>
		<small class="font_mono"
			>created {message.created_formatted_date} {message.created_formatted_time}</small
		>
		<small class="font_mono">type: {message.type}</small>
		<small class="font_mono">direction: {message.direction}</small>
	</div>
</div>

<div class="flex gap_md mb_sm">
	<Copy_To_Clipboard text={JSON.stringify(message.json, null, 2)} attrs={{class: 'plain'}} />
</div>

{#if message.is_pong}
	<div class="mb_md pb_md border_bottom">
		<h3 class="mt_0 mb_sm">Ping Response</h3>
		<div class="field_row">
			<div class="font_weight_500 color_text_subtle">Ping ID</div>
			<div class="font_mono word_break_break_word">{message.ping_id}</div>
		</div>
	</div>
{:else if message.is_prompt}
	<div class="mb_md pb_md border_bottom">
		<h3 class="mt_0 mb_sm">Prompt</h3>
		<pre
			class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm bg_alt rounded w_100">{message
				.prompt_data?.prompt || 'No prompt'}</pre>

		<h3 class="mt_md mb_sm">Request Details</h3>
		<div class="flex flex_column gap_xs">
			<div class="field_row">
				<div class="font_weight_500 color_text_subtle">Model</div>
				<div>{message.prompt_data?.model || 'Unknown'}</div>
			</div>
			<div class="field_row">
				<div class="font_weight_500 color_text_subtle">Provider</div>
				<div>{message.prompt_data?.provider_name || 'Unknown'}</div>
			</div>
			<div class="field_row">
				<div class="font_weight_500 color_text_subtle">Created</div>
				<div>{message.prompt_data?.created || 'Unknown'}</div>
			</div>
			<div class="field_row">
				<div class="font_weight_500 color_text_subtle">Request ID</div>
				<div class="font_mono">{message.prompt_data?.request_id || 'Unknown'}</div>
			</div>
			{#if message.json.completion_request && 'options' in message.json.completion_request}
				{#each Object.entries(message.json.completion_request.options || {}) as [key, value]}
					<div class="field_row">
						<div class="font_weight_500 color_text_subtle">{key}</div>
						<div>{JSON.stringify(value)}</div>
					</div>
				{/each}
			{/if}
		</div>
	</div>
{:else if message.is_completion}
	<div class="mb_md pb_md border_bottom">
		<h3 class="mt_0 mb_sm">Completion</h3>
		<pre
			class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm bg_alt rounded w_100">{message.completion_text ||
				'No completion'}</pre>

		<h3 class="mt_md mb_sm">Response Details</h3>
		<div class="flex flex_column gap_xs">
			<div class="field_row">
				<div class="font_weight_500 color_text_subtle">Request ID</div>
				<div class="font_mono">{message.completion_data?.request_id || 'Unknown'}</div>
			</div>
			<div class="field_row">
				<div class="font_weight_500 color_text_subtle">Created</div>
				<div>{message.completion_data?.created || 'Unknown'}</div>
			</div>
			<div class="field_row">
				<div class="font_weight_500 color_text_subtle">Model</div>
				<div>{message.completion_data?.model || 'Unknown'}</div>
			</div>
			<div class="field_row">
				<div class="font_weight_500 color_text_subtle">Provider</div>
				<div>{message.completion_data?.provider_name || 'Unknown'}</div>
			</div>
			{#if message.json.completion_response?.data}
				{#if message.json.completion_response.data.type === 'ollama'}
					<div class="field_row">
						<div class="font_weight_500 color_text_subtle">Total Duration</div>
						<div>{message.json.completion_response.data.value.total_duration || 'Unknown'}</div>
					</div>
				{:else if message.json.completion_response.data.type === 'claude' && message.json.completion_response.data.value.usage}
					<div class="field_row">
						<div class="font_weight_500 color_text_subtle">Input Tokens</div>
						<div>{message.json.completion_response.data.value.usage.input_tokens || 0}</div>
					</div>
					<div class="field_row">
						<div class="font_weight_500 color_text_subtle">Output Tokens</div>
						<div>{message.json.completion_response.data.value.usage.output_tokens || 0}</div>
					</div>
				{:else if message.json.completion_response.data.type === 'chatgpt' && message.json.completion_response.data.value.usage}
					<div class="field_row">
						<div class="font_weight_500 color_text_subtle">Prompt Tokens</div>
						<div>{message.json.completion_response.data.value.usage.prompt_tokens || 0}</div>
					</div>
					<div class="field_row">
						<div class="font_weight_500 color_text_subtle">Completion Tokens</div>
						<div>{message.json.completion_response.data.value.usage.completion_tokens || 0}</div>
					</div>
					<div class="field_row">
						<div class="font_weight_500 color_text_subtle">Total Tokens</div>
						<div>{message.json.completion_response.data.value.usage.total_tokens || 0}</div>
					</div>
				{:else if message.json.completion_response.data.type === 'gemini'}
					<div class="field_row">
						<div class="font_weight_500 color_text_subtle">Total Tokens</div>
						<div>
							{message.json.completion_response.data.value.usage_metadata?.totalTokenCount || 0}
						</div>
					</div>
				{/if}
			{/if}
		</div>
	</div>
{:else if message.is_file_related}
	<div class="mb_md pb_md border_bottom">
		<h3 class="mt_0 mb_sm">File Information</h3>
		<div class="flex flex_column gap_xs">
			{#if message.path}
				<div class="field_row">
					<div class="font_weight_500 color_text_subtle">Path</div>
					<div class="font_mono word_break_break_word">{message.path}</div>
				</div>
			{/if}
			{#if message.contents !== undefined}
				<div class="field_row">
					<div class="font_weight_500 color_text_subtle">Size</div>
					<div>{message.contents.length || 0} characters</div>
				</div>
				<h4 class="mt_sm mb_xs">Contents</h4>
				<pre
					class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm bg_alt rounded w_100 overflow_auto scrollbar_width_thin"
					style:max-height="300px">{message.contents || ''}</pre>
			{/if}
			{#if message.change}
				<div class="field_row">
					<div class="font_weight_500 color_text_subtle">Change Type</div>
					<div>{message.change.type || 'Unknown'}</div>
				</div>
			{/if}
		</div>
	</div>
{:else if message.is_session}
	<div class="mb_md pb_md border_bottom">
		<h3 class="mt_0 mb_sm">Session Information</h3>
		{#if message.data}
			{#if message.type === 'loaded_session' && message.data.files}
				<div class="field_row">
					<div class="font_weight_500 color_text_subtle">Files Loaded</div>
					<div>{Object.keys(message.data.files).length}</div>
				</div>

				<h4 class="mt_sm mb_xs">Files</h4>
				<div class="w_100 overflow_auto scrollbar_width_thin" style:max-height="200px">
					<table class="w_100">
						<thead>
							<tr>
								<th class="text_align_left p_xs">Path</th>
								<th class="text_align_left p_xs">Size</th>
							</tr>
						</thead>
						<tbody>
							{#each Object.entries(message.data.files) as [path, fileData]}
								<tr>
									<td class="p_xs font_mono size_sm">{path}</td>
									<td class="p_xs"
										>{typeof fileData === 'object' &&
										fileData !== null &&
										'contents' in fileData &&
										typeof fileData.contents === 'string'
											? fileData.contents.length
											: 0} chars</td
									>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{:else}
				<div class="w_100">
					<pre
						class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm bg_alt rounded w_100 overflow_auto scrollbar_width_thin"
						style:max-height="300px">{JSON.stringify(message.data, null, 2)}</pre>
				</div>
			{/if}
		{:else}
			<p>Session {message.type === 'load_session' ? 'loading request' : 'data unavailable'}</p>
		{/if}
	</div>
{/if}

<div>
	<h3 class="mt_md mb_sm">Raw Message Data</h3>
	<pre
		class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm bg_alt rounded w_100">{JSON.stringify(
			message.json,
			null,
			2,
		)}</pre>
</div>

<style>
	.field_row {
		display: grid;
		grid-template-columns: 140px 1fr;
		gap: var(--space_md);
	}
</style>
