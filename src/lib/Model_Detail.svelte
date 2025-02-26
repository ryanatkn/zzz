<script lang="ts">
	import {base} from '$app/paths';
	import {page} from '$app/state';

	import {providers_default} from '$lib/config.js';
	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import type {Model} from '$lib/model.svelte.js';
	import {GLYPH_MODEL} from '$lib/constants.js';

	interface Props {
		model: Model;
	}

	const {model}: Props = $props();

	// TODO BLOCK link the providers below to a page per provider (lookup from provider_default/context)

	const at_detail_page = $derived(page.url.pathname === `${base}/models/${model.name}`);
</script>

<div class="panel p_lg">
	{#if at_detail_page}
		<h1>
			{GLYPH_MODEL}
			{model.name}
		</h1>
	{:else}
		<h2>
			<Model_Link {model} icon />
		</h2>
	{/if}
	<div class="mb_lg font_mono">
		<!-- TODO hacky -->
		<Provider_Link
			provider={providers_default.find((p) => p.name === model.provider_name)!}
			icon
			show_name
		/>
	</div>
	{#if model.tags.length}
		<ul class="unstyled flex gap_xs">
			{#each model.tags as tag (tag)}
				<span class="chip size_sm font_weight_400">{tag}</span>
			{/each}
		</ul>
	{/if}
	{#if model.context_window}
		<div>
			Context window: {model.context_window.toLocaleString()} tokens
		</div>
	{/if}
	{#if model.output_token_limit}
		<div>
			Output limit: {model.output_token_limit.toLocaleString()} tokens
		</div>
	{/if}
	{#if model.parameter_count}
		<div>
			Parameters: {model.parameter_count.toLocaleString()}B
		</div>
	{/if}
	{#if model.filesize}
		<div>
			File size: {model.filesize}GB
		</div>
	{/if}
	{#if model.architecture}
		<div>
			Architecture: {model.architecture}
		</div>
	{/if}
	{#if model.embedding_length}
		<div>
			Embedding length: {model.embedding_length}
		</div>
	{/if}
	{#if model.cost_input || model.cost_output}
		<div>
			{#if model.cost_input}
				<div>Input: ${model.cost_input.toFixed(2)} / 1M tokens</div>
			{/if}
			{#if model.cost_output}
				<div>Output: ${model.cost_output.toFixed(2)} / 1M tokens</div>
			{/if}
		</div>
	{/if}
	{#if model.training_cutoff}
		<div>Training cutoff: {model.training_cutoff}</div>
	{/if}
	{#if model.provider_name === 'ollama'}
		<h3>Ollama model info</h3>
		{#if model.ollama_model_info}
			<pre class="overflow_hidden"><code class="overflow_auto p_md"
					>{JSON.stringify(model.ollama_model_info, null, '\t')}</code
				></pre>
		{:else}
			<p>
				<small class="bg_e_1 px_sm radius_xs">not downloaded</small>
				<!-- TODO add a button to download it -->
			</p>
		{/if}
	{/if}
</div>
