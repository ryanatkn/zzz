<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import {strip_start} from '@ryanatkn/belt/string.js';

	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_PROMPT, GLYPH_RESPONSE, GLYPH_FILE, GLYPH_ACTION} from '$lib/glyphs.js';
	import type {Action} from '$lib/action.svelte.js';

	interface Props {
		action: Action;
	}

	const {action}: Props = $props();
</script>

<div class="mb_md">
	<div class="size_lg">
		{#if action.is_prompt}
			<Glyph icon={GLYPH_PROMPT} /> Prompt
		{:else if action.is_completion}
			<Glyph icon={GLYPH_RESPONSE} /> Response
		{:else if action.is_file_related}
			<Glyph icon={GLYPH_FILE} /> File {action.type}
		{:else}
			<Glyph icon={GLYPH_ACTION} /> {action.type}
		{/if}
		<small class="color_subtle ml_xs">{action.direction}</small>
	</div>
	<div class="flex flex_column gap_xs mt_sm">
		<small class="font_mono">ID: {action.id}</small>
		<small class="font_mono"
			>created {action.created_formatted_date} {action.created_formatted_time}</small
		>
		<small class="font_mono">type: {action.type}</small>
		<small class="font_mono">direction: {action.direction}</small>
	</div>
</div>

<div class="flex gap_md mb_sm">
	<Copy_To_Clipboard text={JSON.stringify(action.json, null, 2)} attrs={{class: 'plain'}} />
</div>

{#if action.is_pong}
	<section class="pb_md border_bottom">
		<h3 class="mt_0 mb_sm">Ping Response</h3>
		<div class="field_row">
			<div class="font_weight_600 color_text_subtle">Ping id</div>
			<div class="font_mono word_break_break_word">{action.ping_id}</div>
		</div>
	</section>
{:else if action.is_prompt}
	<section class="pb_md border_bottom">
		<h3 class="mt_0 mb_sm">Prompt</h3>
		<pre class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm w_100">{action
				.prompt_data?.prompt || 'No prompt'}</pre>

		<h3>Request Details</h3>
		<div class="flex flex_column gap_xs">
			<div class="field_row">
				<div class="font_weight_600 color_text_subtle">Model</div>
				<div>{action.prompt_data?.model || 'Unknown'}</div>
			</div>
			<div class="field_row">
				<div class="font_weight_600 color_text_subtle">Provider</div>
				<div>{action.prompt_data?.provider_name || 'Unknown'}</div>
			</div>
			<div class="field_row">
				<div class="font_weight_600 color_text_subtle">Created</div>
				<div>{action.prompt_data?.created || 'Unknown'}</div>
			</div>
			<div class="field_row">
				<div class="font_weight_600 color_text_subtle">Request id</div>
				<div class="font_mono">{action.prompt_data?.request_id || 'Unknown'}</div>
			</div>
			{#if action.json.completion_request && 'options' in action.json.completion_request}
				{#each Object.entries(action.json.completion_request.options || {}) as [key, value]}
					<div class="field_row">
						<div class="font_weight_600 color_text_subtle">{key}</div>
						<div>{JSON.stringify(value)}</div>
					</div>
				{/each}
			{/if}
		</div>
	</section>
{:else if action.is_completion}
	<section class="pb_md border_bottom">
		<h3 class="mt_0 mb_sm">Completion</h3>
		<pre
			class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm w_100">{action.completion_text ||
				'No completion'}</pre>

		<h3>Response Details</h3>
		<div class="flex flex_column gap_xs">
			<div class="field_row">
				<div class="font_weight_600 color_text_subtle">Request id</div>
				<div class="font_mono">{action.completion_data?.request_id || 'Unknown'}</div>
			</div>
			<div class="field_row">
				<div class="font_weight_600 color_text_subtle">Created</div>
				<div>{action.completion_data?.created || 'Unknown'}</div>
			</div>
			<div class="field_row">
				<div class="font_weight_600 color_text_subtle">Model</div>
				<div>{action.completion_data?.model || 'Unknown'}</div>
			</div>
			<div class="field_row">
				<div class="font_weight_600 color_text_subtle">Provider</div>
				<div>{action.completion_data?.provider_name || 'Unknown'}</div>
			</div>
			{#if action.json.completion_response?.data}
				{#if action.json.completion_response.data.type === 'ollama'}
					<div class="field_row">
						<div class="font_weight_600 color_text_subtle">Total Duration</div>
						<div>{action.json.completion_response.data.value.total_duration || 'Unknown'}</div>
					</div>
				{:else if action.json.completion_response.data.type === 'claude' && action.json.completion_response.data.value.usage}
					<div class="field_row">
						<div class="font_weight_600 color_text_subtle">Input Tokens</div>
						<div>{action.json.completion_response.data.value.usage.input_tokens || 0}</div>
					</div>
					<div class="field_row">
						<div class="font_weight_600 color_text_subtle">Output Tokens</div>
						<div>{action.json.completion_response.data.value.usage.output_tokens || 0}</div>
					</div>
				{:else if action.json.completion_response.data.type === 'chatgpt' && action.json.completion_response.data.value.usage}
					<div class="field_row">
						<div class="font_weight_600 color_text_subtle">Prompt Tokens</div>
						<div>{action.json.completion_response.data.value.usage.prompt_tokens || 0}</div>
					</div>
					<div class="field_row">
						<div class="font_weight_600 color_text_subtle">Completion Tokens</div>
						<div>{action.json.completion_response.data.value.usage.completion_tokens || 0}</div>
					</div>
					<div class="field_row">
						<div class="font_weight_600 color_text_subtle">Total Tokens</div>
						<div>{action.json.completion_response.data.value.usage.total_tokens || 0}</div>
					</div>
				{:else if action.json.completion_response.data.type === 'gemini'}
					<div class="field_row">
						<div class="font_weight_600 color_text_subtle">Total Tokens</div>
						<div>
							{action.json.completion_response.data.value.usage_metadata?.totalTokenCount || 0}
						</div>
					</div>
				{/if}
			{/if}
		</div>
	</section>
{:else if action.is_file_related}
	<section class="pb_md border_bottom">
		<h3>file information</h3>
		<div class="flex flex_column gap_xs">
			{#if action.path}
				<div class="field_row">
					<div class="font_weight_600 color_text_subtle">Path</div>
					<div class="font_mono word_break_break_word">{action.path}</div>
				</div>
			{/if}
			{#if action.content !== undefined}
				<div class="field_row">
					<div class="font_weight_600 color_text_subtle">Size</div>
					<div>{action.content.length || 0} characters</div>
				</div>
				<h4 class="mt_sm mb_xs">Contents</h4>
				<pre
					class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm w_100 overflow_auto scrollbar_width_thin"
					style:max-height="300px">{action.content || ''}</pre>
			{/if}
			{#if action.change}
				<div class="field_row">
					<div class="font_weight_600 color_text_subtle">Change Type</div>
					<div>{action.change.type || 'Unknown'}</div>
				</div>
			{/if}
		</div>
	</section>
{:else if action.is_session}
	<section class="pb_md border_bottom">
		<h3>session information</h3>
		{#if action.data}
			{#if action.type === 'loaded_session' && action.data.files}
				<div class="field_row">
					<div class="font_weight_600 color_text_subtle">files loaded</div>
					<div>{Object.keys(action.data.files).length}</div>
				</div>

				<h4 class="mt_sm mb_xs">files</h4>
				<div class="w_100 overflow_auto scrollbar_width_thin" style:max-height="200px">
					<table class="w_100">
						<thead>
							<tr>
								<th class="text_align_left p_xs">path</th>
								<th class="text_align_left p_xs">size</th>
							</tr>
						</thead>
						<tbody>
							{#each action.data.files as file_data}
								<tr>
									<td class="p_xs font_mono size_sm"
										>{strip_start(file_data.id, file_data.source_dir)}</td
									>
									<td class="p_xs"
										>{typeof file_data === 'object' &&
										file_data !== null &&
										'contents' in file_data &&
										typeof file_data.contents === 'string'
											? file_data.contents.length
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
						class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm w_100 overflow_auto scrollbar_width_thin"
						style:max-height="300px">{JSON.stringify(action.data, null, 2)}</pre>
				</div>
			{/if}
		{:else}
			<p>session {action.type === 'load_session' ? 'loading request' : 'data unavailable'}</p>
		{/if}
	</section>
{/if}

<section>
	<h3>raw action data</h3>
	<pre
		class="font_mono size_sm white_space_pre_wrap word_break_break_word p_sm w_100">{JSON.stringify(
			action.json,
			null,
			2,
		)}</pre>
</section>

<style>
	.field_row {
		display: grid;
		grid-template-columns: 140px 1fr;
		gap: var(--space_md);
	}
</style>
