<script lang="ts">
	// @slop

	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import {strip_start} from '@ryanatkn/belt/string.js';

	import Glyph from '$lib/Glyph.svelte';
	import {get_glyph_for_action_kind} from '$lib/glyphs.js';
	import type {Action} from '$lib/action.svelte.js';

	interface Props {
		action: Action;
	}

	const {action}: Props = $props();

	// TODO this is all hacky, just proof of concept stuff
</script>

<div class="mb_md">
	<div class="font_size_lg">
		<Glyph glyph={get_glyph_for_action_kind(action.kind)} />
		{#if action.is_prompt}
			Prompt
		{:else if action.is_session}
			Session
		{:else if action.is_file_related}
			File {action.method}
		{:else}
			{action.method}
		{/if}
		{#if action.kind === 'request_response'}
			<small class="color_text_subtle">
				{#if action.has_response}
					(complete)
				{:else}
					(pending...)
				{/if}
			</small>
		{/if}
	</div>
	<div class="display_flex flex_column gap_xs mt_sm">
		<small class="font_family_mono">id: {action.id}</small>
		<small class="font_family_mono">
			created {action.created_formatted_datetime}
			{action.created_formatted_time}
		</small>
		{#if action.updated_formatted_date}
			<small class="font_family_mono">
				updated {action.updated_formatted_date}
				{action.updated_formatted_time}
			</small>
		{/if}
		<small class="font_family_mono">method: {action.method}</small>
		<small class="font_family_mono">kind: {action.kind}</small>
		{#if action.jsonrpc_message_id}
			<small class="font_family_mono">request id: {action.jsonrpc_message_id}</small>
		{/if}
	</div>
</div>

<div class="display_flex gap_md mb_sm">
	<Copy_To_Clipboard text={JSON.stringify(action.json, null, 2)} attrs={{class: 'plain'}} />
</div>

{#if action.is_ping}
	<section class="pb_md border_bottom">
		<h3 class="mt_0 mb_sm">Ping {action.has_response ? 'complete' : 'pending'}</h3>
		{#if action.ping_id}
			<div class="field_row">
				<div class="font_weight_600 color_text_subtle">Ping id</div>
				<div class="font_family_mono word_break_break_word">{action.ping_id}</div>
			</div>
		{/if}
		{#if action.has_error}
			<div class="field_row">
				<div class="font_weight_600 color_text_subtle">Error</div>
				<div class="color_c">{action.error.message}</div>
			</div>
		{/if}
	</section>
{:else if action.is_prompt}
	<section class="pb_md border_bottom">
		<h3 class="mt_0 mb_sm">Prompt</h3>
		<pre
			class="font_family_mono font_size_sm white_space_pre_wrap word_break_break_word p_sm w_100">{action
				.prompt_data?.prompt || 'No prompt'}</pre>

		<h3>Request details</h3>
		<div class="display_flex flex_column gap_xs">
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
				<div class="font_family_mono">{action.prompt_data?.request_id || 'Unknown'}</div>
			</div>
		</div>
	</section>

	{#if action.has_response}
		<section class="pb_md border_bottom">
			<h3 class="mt_0 mb_sm">Completion</h3>
			{#if action.has_error}
				<div class="color_c p_sm">
					Error: {action.error.message}
					{#if action.error.code}
						(code: {action.error.code})
					{/if}
				</div>
			{:else}
				<pre
					class="font_family_mono font_size_sm white_space_pre_wrap word_break_break_word p_sm w_100">{action.completion_text ||
						'No completion'}</pre>

				<h3>Response details</h3>
				<div class="display_flex flex_column gap_xs">
					<div class="field_row">
						<div class="font_weight_600 color_text_subtle">Request id</div>
						<div class="font_family_mono">{action.completion_data?.request_id || 'Unknown'}</div>
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
					{#if action.completion_response?.data}
						{#if action.completion_response.data.type === 'ollama'}
							<div class="field_row">
								<div class="font_weight_600 color_text_subtle">Total duration</div>
								<div>{action.completion_response.data.value.total_duration || 'Unknown'}</div>
							</div>
						{:else if action.completion_response.data.type === 'claude' && action.completion_response.data.value.usage}
							<div class="field_row">
								<div class="font_weight_600 color_text_subtle">Input tokens</div>
								<div>{action.completion_response.data.value.usage.input_tokens || 0}</div>
							</div>
							<div class="field_row">
								<div class="font_weight_600 color_text_subtle">Output tokens</div>
								<div>{action.completion_response.data.value.usage.output_tokens || 0}</div>
							</div>
						{:else if action.completion_response.data.type === 'chatgpt' && action.completion_response.data.value.usage}
							<div class="field_row">
								<div class="font_weight_600 color_text_subtle">Prompt tokens</div>
								<div>{action.completion_response.data.value.usage.prompt_tokens || 0}</div>
							</div>
							<div class="field_row">
								<div class="font_weight_600 color_text_subtle">Completion tokens</div>
								<div>{action.completion_response.data.value.usage.completion_tokens || 0}</div>
							</div>
							<div class="field_row">
								<div class="font_weight_600 color_text_subtle">Total tokens</div>
								<div>{action.completion_response.data.value.usage.total_tokens || 0}</div>
							</div>
						{:else if action.completion_response.data.type === 'gemini'}
							<div class="field_row">
								<div class="font_weight_600 color_text_subtle">Total tokens</div>
								<div>
									{action.completion_response.data.value.usage_metadata?.totalTokenCount || 0}
								</div>
							</div>
						{/if}
					{/if}
				</div>
			{/if}
		</section>
	{/if}
{:else if action.is_file_related}
	<section class="pb_md border_bottom">
		<h3>File information</h3>
		<div class="display_flex flex_column gap_xs">
			{#if action.path}
				<div class="field_row">
					<div class="font_weight_600 color_text_subtle">Path</div>
					<div class="font_family_mono word_break_break_word">{action.path}</div>
				</div>
			{/if}
			{#if action.content !== undefined}
				<div class="field_row">
					<div class="font_weight_600 color_text_subtle">Size</div>
					<div>{action.content.length || 0} characters</div>
				</div>
				<h4 class="mt_sm mb_xs">Contents</h4>
				<pre
					class="font_family_mono font_size_sm white_space_pre_wrap word_break_break_word p_sm w_100 overflow_auto scrollbar_width_thin"
					style:max-height="300px">{action.content || ''}</pre>
			{/if}
			{#if action.change}
				<div class="field_row">
					<div class="font_weight_600 color_text_subtle">Change Type</div>
					<div>{action.change.type}</div>
				</div>
			{/if}
			{#if action.source_file}
				<div class="field_row">
					<div class="font_weight_600 color_text_subtle">Source File</div>
					<div class="font_family_mono">
						{strip_start(action.source_file.id, action.source_file.source_dir)}
					</div>
				</div>
			{/if}
		</div>
		{#if action.has_error}
			<div class="color_c mt_sm">
				Error: {action.error.message}
			</div>
		{/if}
	</section>
{:else if action.is_session}
	<section class="pb_md border_bottom">
		<h3>Session information</h3>
		{#if action.has_response}
			{#if action.has_error}
				<div class="color_c">
					Error loading session: {action.error.message}
				</div>
			{:else if action.data}
				{#if action.data.files}
					<div class="field_row">
						<div class="font_weight_600 color_text_subtle">Files loaded</div>
						<div>{action.data.files.length}</div>
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
								{#each action.data.files as file_data (file_data.id)}
									<tr>
										<td class="p_xs font_family_mono font_size_sm"
											>{strip_start(file_data.id, file_data.source_dir)}</td
										>
										<td class="p_xs">{file_data.contents?.length || 0} chars</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{:else}
					<div class="w_100">
						<pre
							class="font_family_mono font_size_sm white_space_pre_wrap word_break_break_word p_sm w_100 overflow_auto scrollbar_width_thin"
							style:max-height="300px">{JSON.stringify(action.data, null, 2)}</pre>
					</div>
				{/if}
			{:else}
				<p>No session data</p>
			{/if}
		{:else}
			<p>Loading session...</p>
		{/if}
	</section>
{/if}

{#if action.jsonrpc_request}
	<section class="pb_md border_bottom">
		<h3>JSON-RPC Request</h3>
		<pre
			class="font_family_mono font_size_sm white_space_pre_wrap word_break_break_word p_sm w_100">{JSON.stringify(
				action.jsonrpc_request,
				null,
				2,
			)}</pre>
	</section>
{/if}

{#if action.jsonrpc_response}
	<section class="pb_md border_bottom">
		<h3>JSON-RPC Response</h3>
		<pre
			class="font_family_mono font_size_sm white_space_pre_wrap word_break_break_word p_sm w_100">{JSON.stringify(
				action.jsonrpc_response,
				null,
				2,
			)}</pre>
	</section>
{/if}

{#if action.jsonrpc_notification}
	<section class="pb_md border_bottom">
		<h3>JSON-RPC Notification</h3>
		<pre
			class="font_family_mono font_size_sm white_space_pre_wrap word_break_break_word p_sm w_100">{JSON.stringify(
				action.jsonrpc_notification,
				null,
				2,
			)}</pre>
	</section>
{/if}

<section>
	<h3>Raw action data</h3>
	<pre
		class="font_family_mono font_size_sm white_space_pre_wrap word_break_break_word p_sm w_100">{JSON.stringify(
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
