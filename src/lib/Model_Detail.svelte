<script lang="ts">
	import {base} from '$app/paths';
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import type {Model} from '$lib/model.svelte.js';
	import {GLYPH_MODEL} from '$lib/glyphs.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import Glyph from '$lib/Glyph.svelte';

	interface Props {
		model: Model;
		attrs?: SvelteHTMLElements['div'] | undefined;
	}

	const {model, attrs}: Props = $props();

	const app = frontend_context.get();

	const at_detail_page = $derived(page.url.pathname === `${base}/models/${model.name}`);
	const provider = $derived(app.providers.find_by_name(model.provider_name));
</script>

<div {...attrs} class="panel p_lg {attrs?.class}">
	<div class="row">
		<div class="glyph_container">
			<Glyph glyph={GLYPH_MODEL} size="var(--icon_size_xl)" />
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
			<div class="display_flex font_family_mono ml_sm mb_md font_size_lg">
				<Provider_Link {provider} attrs={{class: 'row gap_sm'}} icon="svg" />
			</div>
			{#if model.tags.length}
				<ul class="unstyled display_flex gap_xs mb_md">
					{#each model.tags as tag (tag)}
						<small class="chip font_weight_400">{tag}</small>
					{/each}
				</ul>
			{/if}
		</div>
	</div>

	<section>
		<h2>Specs</h2>
		<div class="specs_grid">
			{#if model.context_window}
				<div>
					<strong>context window:</strong>
					{model.context_window.toLocaleString()} tokens
				</div>
			{/if}
			{#if model.output_token_limit}
				<div>
					<strong>output limit:</strong>
					{model.output_token_limit.toLocaleString()} tokens
				</div>
			{/if}
			{#if model.parameter_count}
				<div>
					<strong>parameters:</strong>
					{model.parameter_count.toLocaleString()}B
				</div>
			{/if}
			{#if model.filesize}
				<div>
					<strong>file size:</strong>
					{model.filesize}GB
				</div>
			{/if}
			{#if model.architecture}
				<div>
					<strong>architecture:</strong>
					{model.architecture}
				</div>
			{/if}
			{#if model.embedding_length}
				<div>
					<strong>embedding length:</strong>
					{model.embedding_length}
				</div>
			{/if}
			{#if model.training_cutoff}
				<div>
					<strong>training cutoff:</strong>
					{model.training_cutoff}
				</div>
			{/if}
		</div>

		{#if model.cost_input || model.cost_output}
			<section>
				<h3>Pricing</h3>
				{#if model.cost_input}
					<div><strong>input:</strong> ${model.cost_input.toFixed(2)} / 1M tokens</div>
				{/if}
				{#if model.cost_output}
					<div><strong>output:</strong> ${model.cost_output.toFixed(2)} / 1M tokens</div>
				{/if}
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
						<small class="bg_e_1 px_sm border_radius_xs">not downloaded</small>
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

	section {
		margin-top: var(--space_lg);
	}
</style>
