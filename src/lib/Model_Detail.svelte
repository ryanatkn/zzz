<script lang="ts">
	import {providers_default} from '$lib/config.js';
	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import type {Model_Json} from './model.svelte.js';

	interface Props {
		model: Model_Json; // TODO Model class instance
	}

	const {model}: Props = $props();

	// TODO BLOCK link the providers below to a page per provider (lookup from provider_default/context)
</script>

<div class="model_card">
	<h2 class="model_name">
		<Model_Link {model} />
	</h2>
	<div class="model_provider">
		<!-- TODO hacky -->
		<Provider_Link provider={providers_default.find((p) => p.name === model.provider_name)!}
			>{model.provider_name}</Provider_Link
		>
	</div>
	{#if model.tags.length}
		<div class="model_tags">
			{#each model.tags as tag}
				<span class="model_tag">{tag}</span>
			{/each}
		</div>
	{/if}
	{#if model.context_window}
		<div class="model_stat">
			Context window: {model.context_window.toLocaleString()} tokens
		</div>
	{/if}
	{#if model.output_token_limit}
		<div class="model_stat">
			Output limit: {model.output_token_limit.toLocaleString()} tokens
		</div>
	{/if}
	{#if model.parameter_count}
		<div class="model_stat">
			Parameters: {model.parameter_count.toLocaleString()}B
		</div>
	{/if}
	{#if model.filesize}
		<div class="model_stat">
			File size: {model.filesize}GB
		</div>
	{/if}
	{#if model.architecture}
		<div class="model_stat">
			Architecture: {model.architecture}
		</div>
	{/if}
	{#if model.cost_input || model.cost_output}
		<div class="model_costs">
			{#if model.cost_input}
				<div class="model_cost">Input: ${model.cost_input.toFixed(2)} / 1M tokens</div>
			{/if}
			{#if model.cost_output}
				<div class="model_cost">Output: ${model.cost_output.toFixed(2)} / 1M tokens</div>
			{/if}
		</div>
	{/if}
	{#if model.training_cutoff}
		<div class="model_cutoff">Training cutoff: {model.training_cutoff}</div>
	{/if}
</div>

<style>
	.model_card {
		background: var(--fg_1);
		border-radius: var(--radius_md);
		padding: var(--space_lg);
	}

	.model_name {
		font-size: var(--size_lg);
		margin: 0 0 var(--space_sm);
	}

	.model_provider {
		color: var(--text_2);
		margin-bottom: var(--space_sm);
	}

	.model_tags {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space_xs);
		margin-bottom: var(--space_sm);
	}

	.model_tag {
		background: var(--fg_1);
		padding: var(--space_xs) var(--space_sm);
		border-radius: var(--radius_sm);
		font-size: var(--size_sm);
	}

	.model_stat {
		color: var(--text_2);
		margin-bottom: var(--space_xs);
	}

	.model_costs {
		margin: var(--space_sm) 0;
		padding: var(--space_sm);
		background: var(--fg_1);
		border-radius: var(--radius_sm);
	}

	.model_cost {
		color: var(--text_2);
	}

	.model_cutoff {
		font-style: italic;
		color: var(--color_text_3);
		font-size: var(--size_sm);
		margin-top: var(--space_sm);
	}
</style>
