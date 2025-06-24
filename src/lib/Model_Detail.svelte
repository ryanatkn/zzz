<script lang="ts">
	import {base} from '$app/paths';
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import type {Model} from '$lib/model.svelte.js';
	import {GLYPH_MODEL, GLYPH_REFRESH, GLYPH_ERROR, GLYPH_CHECKMARK} from '$lib/glyphs.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import Glyph from '$lib/Glyph.svelte';
	import {format_short_date} from '$lib/time_helpers.js';

	interface Props {
		model: Model;
		attrs?: SvelteHTMLElements['div'] | undefined;
	}

	const {model, attrs}: Props = $props();

	const app = frontend_context.get();

	const at_detail_page = $derived(page.url.pathname === `${base}/models/${model.name}`);
	const provider = $derived(app.providers.find_by_name(model.provider_name));

	const load_ollama_details = async () => {
		if (model.provider_name === 'ollama' && model.needs_ollama_details) {
			await app.ollama.show_model(model.name);
		}
	};

	const reload_ollama_details = async () => {
		if (model.provider_name === 'ollama') {
			await app.ollama.refresh_model_details(model.name);
		}
	};

	// Format file size nicely
	const format_file_size = (gb: number): string => {
		if (gb < 1) {
			return `${Math.round(gb * 1024)} MB`;
		}
		return `${gb.toFixed(1)} GB`;
	};

	// TODO BLOCK should be able to start a chat from a button here with this model
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
			{#if model.downloaded !== undefined}
				<div class="mb_md">
					{#if model.downloaded}
						<small class="chip bg_b_1 color_b px_sm">{GLYPH_CHECKMARK} downloaded</small>
						{#if model.ollama_modified_at}
							<small class="ml_sm">modified {format_short_date(model.ollama_modified_at)}</small>
						{/if}
					{:else}
						<small class="chip bg_e_1 color_e px_sm">not downloaded</small>
					{/if}
				</div>
			{/if}
		</div>
	</div>

	{#if model.provider_name !== 'ollama'}
		<aside class="mt_xl3">
			⚠️ This information is incomplete and may be incorrect or outdated.
		</aside>
	{/if}

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
					{format_file_size(model.filesize)}
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
					{model.embedding_length.toLocaleString()}
				</div>
			{/if}
			{#if model.training_cutoff}
				<div>
					<strong>training cutoff:</strong>
					{model.training_cutoff}
				</div>
			{/if}

			{#if model.provider_name === 'ollama' && model.ollama_list_data?.details}
				{#if model.ollama_list_data.details.format}
					<div>
						<strong>format:</strong>
						{model.ollama_list_data.details.format}
					</div>
				{/if}
				{#if model.ollama_list_data.details.quantization_level}
					<div>
						<strong>quantization:</strong>
						{model.ollama_list_data.details.quantization_level}
					</div>
				{/if}
				{#if model.ollama_list_data.details.families.length}
					<div>
						<strong>families:</strong>
						{model.ollama_list_data.details.families.join(', ')}
					</div>
				{/if}
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
				<div class="display_flex justify_content_space_between align_items_center mb_md">
					<h3 class="mt_0 mb_0">Ollama Details</h3>
					<div class="display_flex gap_sm">
						{#if model.ollama_details_loaded}
							<button
								type="button"
								class="plain compact"
								onclick={reload_ollama_details}
								title="reload details"
							>
								<Glyph glyph={GLYPH_REFRESH} /> reload
							</button>
						{:else if model.needs_ollama_details}
							<button
								type="button"
								class="compact"
								onclick={load_ollama_details}
								disabled={model.ollama_details_loading}
							>
								{#if model.ollama_details_loading}
									<Pending_Animation inline /> loading...
								{:else}
									<Glyph glyph={GLYPH_REFRESH} /> load details
								{/if}
							</button>
						{/if}
					</div>
				</div>

				{#if model.ollama_details_error}
					<div class="panel p_sm bg_c_1 color_c mb_md">
						<Glyph glyph={GLYPH_ERROR} /> failed to load details: {model.ollama_details_error}
					</div>
				{/if}

				{#if model.ollama_list_data}
					<div class="subsection">
						<h4>model info</h4>
						<div class="info_grid">
							<div>
								<strong>digest:</strong>
								<code class="font_size_sm">{model.ollama_list_data.digest.slice(0, 12)}...</code>
							</div>
							{#if model.ollama_list_data.size}
								<div>
									<strong>size:</strong>
									{(model.ollama_list_data.size / (1024 * 1024 * 1024)).toFixed(2)} GB
								</div>
							{/if}
							{#if model.ollama_list_data.details?.parent_model}
								<div>
									<strong>parent:</strong>
									{model.ollama_list_data.details.parent_model}
								</div>
							{/if}
						</div>
					</div>
				{/if}

				{#if model.ollama_details}
					{#if model.ollama_details.system}
						<div class="subsection">
							<h4>system prompt</h4>
							<pre class="code_block">{model.ollama_details.system}</pre>
						</div>
					{/if}

					{#if model.ollama_details.template}
						<div class="subsection">
							<h4>template</h4>
							<pre class="code_block">{model.ollama_details.template}</pre>
						</div>
					{/if}

					{#if model.ollama_details.modelfile}
						<details class="subsection">
							<summary><h4 class="inline">modelfile</h4></summary>
							<pre class="code_block mt_sm">{model.ollama_details.modelfile}</pre>
						</details>
					{/if}

					{#if model.ollama_details.model_info && Object.keys(model.ollama_details.model_info).length > 0}
						<details class="subsection">
							<summary><h4 class="inline">model info</h4></summary>
							<pre class="code_block mt_sm">{JSON.stringify(
									model.ollama_details.model_info,
									null,
									2,
								)}</pre>
						</details>
					{/if}

					{#if model.ollama_details.license}
						<div class="subsection">
							<h4>License</h4>
							<pre class="code_block">{model.ollama_details.license}</pre>
						</div>
					{/if}
				{:else if !model.ollama_details_loading && !model.needs_ollama_details}
					<p class="font_size_sm">
						Click "load details" to see system prompt, template, and more information.
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

	.specs_grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: var(--space_sm);
		margin-top: var(--space_sm);
	}

	.info_grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: var(--space_sm);
		margin-top: var(--space_xs);
	}

	.subsection {
		margin-top: var(--space_md);
	}

	.subsection h4 {
		margin-top: 0;
		margin-bottom: var(--space_xs);
	}

	h4.inline {
		display: inline;
		margin: 0;
		cursor: pointer;
	}

	.code_block {
		background: var(--bg_2);
		padding: var(--space_sm);
		border-radius: var(--radius_xs);
		overflow-x: auto;
		max-height: 300px;
		font-size: var(--font_size_sm);
		white-space: pre-wrap;
		word-break: break-word;
	}

	details summary {
		cursor: pointer;
		user-select: none;
	}

	details summary:hover {
		opacity: 0.8;
	}

	code {
		font-family: var(--font_mono);
	}
</style>
