<script lang="ts">
	import {providers_default} from '$lib/config.js';
	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import type {Model} from '$lib/model.svelte.js';
	import {SYMBOL_PROVIDER} from './constants.js';

	interface Props {
		model: Model;
	}

	const {model}: Props = $props();

	// TODO BLOCK link the providers below to a page per provider (lookup from provider_default/context)
</script>

<div class="panel p_lg">
	<div class="size_xl mb_lg">
		<Model_Link {model} />
	</div>
	<div class="mb_lg font_mono">
		<!-- TODO hacky -->
		<Provider_Link provider={providers_default.find((p) => p.name === model.provider_name)!}
			>{SYMBOL_PROVIDER} {model.provider_name}</Provider_Link
		>
	</div>
	<!-- {#if model.provider_name === 'ollama'}
		{#if !model.ollama_model_info}
			TODO maybe show an error?
		{/if}
	{/if} -->
	{#if model.tags.length}
		<ul class="unstyled flex gap_xs">
			{#each model.tags as tag (tag)}
				<span class="chip">{tag}</span>
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
</div>
