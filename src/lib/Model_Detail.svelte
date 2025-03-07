<script lang="ts">
	import {base} from '$app/paths';
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import type {Model} from '$lib/model.svelte.js';
	import {GLYPH_MODEL} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		model: Model;
		attrs?: SvelteHTMLElements['div'];
	}

	const {model, attrs}: Props = $props();

	const zzz = zzz_context.get();

	// TODO BLOCK link the providers below to a page per provider (lookup from provider_default/context)

	const at_detail_page = $derived(page.url.pathname === `${base}/models/${model.name}`);
	const provider = $derived(zzz.providers.find_by_name(model.provider_name));
</script>

<div {...attrs} class="panel p_lg {attrs?.class}">
	<div class="row">
		<div class="glyph_container">
			<span class="glyph" style:font-size="var(--icon_size_xl)">{GLYPH_MODEL}</span>
		</div>
		<div class="pl_xl">
			{#if at_detail_page}
				<h1 class="mb_md">
					{model.name}
				</h1>
			{:else}
				<h2>
					<Model_Link {model} />
				</h2>
			{/if}
			<div class="flex font_mono ml_sm mb_md size_lg">
				<Provider_Link {provider} attrs={{class: 'row gap_sm'}} icon="svg" />
			</div>
			{#if model.tags.length}
				<ul class="unstyled flex gap_xs mb_md">
					{#each model.tags as tag (tag)}
						<span class="chip size_sm font_weight_400">{tag}</span>
					{/each}
				</ul>
			{/if}
		</div>
	</div>

	<section>
		<h2>Model specifications</h2>
		<div class="specs_grid">
			{#if model.context_window}
				<div>
					<strong>Context window:</strong>
					{model.context_window.toLocaleString()} tokens
				</div>
			{/if}
			{#if model.output_token_limit}
				<div>
					<strong>Output limit:</strong>
					{model.output_token_limit.toLocaleString()} tokens
				</div>
			{/if}
			{#if model.parameter_count}
				<div>
					<strong>Parameters:</strong>
					{model.parameter_count.toLocaleString()}B
				</div>
			{/if}
			{#if model.filesize}
				<div>
					<strong>File size:</strong>
					{model.filesize}GB
				</div>
			{/if}
			{#if model.architecture}
				<div>
					<strong>Architecture:</strong>
					{model.architecture}
				</div>
			{/if}
			{#if model.embedding_length}
				<div>
					<strong>Embedding length:</strong>
					{model.embedding_length}
				</div>
			{/if}
			{#if model.training_cutoff}
				<div>
					<strong>Training cutoff:</strong>
					{model.training_cutoff}
				</div>
			{/if}
		</div>

		{#if model.cost_input || model.cost_output}
			<section>
				<h3>Pricing</h3>
				<div class="specs_grid">
					{#if model.cost_input}
						<div><strong>Input:</strong> ${model.cost_input.toFixed(2)} / 1M tokens</div>
					{/if}
					{#if model.cost_output}
						<div><strong>Output:</strong> ${model.cost_output.toFixed(2)} / 1M tokens</div>
					{/if}
				</div>
			</section>
		{/if}

		{#if model.provider_name === 'ollama'}
			<section>
				<h3>Ollama model info</h3>
				{#if model.ollama_model_info}
					<pre class="overflow_hidden"><code class="overflow_auto scrollbar_width_thin p_md"
							>{JSON.stringify(model.ollama_model_info, null, '\t')}</code
						></pre>
				{:else}
					<p>
						<small class="bg_e_1 px_sm radius_xs">not downloaded</small>
						<!-- TODO add a button to download it -->
					</p>
				{/if}
			</section>
		{/if}
	</section>
</div>

<style>
	.glyph_container {
		display: flex;
		align-items: center;
		justify-content: center;
		min-width: var(--icon_size_xl);
		line-height: 1;
	}
	.specs_grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
		gap: var(--space_md);
		margin-bottom: var(--space_md);
	}
	section {
		margin-top: var(--space_lg);
	}
</style>
