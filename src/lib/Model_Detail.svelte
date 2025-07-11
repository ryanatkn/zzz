<script lang="ts">
	// @slop Claude Sonnet 3.7

	import {base} from '$app/paths';
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {onMount} from 'svelte';

	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import type {Model} from '$lib/model.svelte.js';
	import {GLYPH_MODEL, GLYPH_CHECKMARK, GLYPH_ADD, GLYPH_XMARK} from '$lib/glyphs.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import Glyph from '$lib/Glyph.svelte';
	import Model_Contextmenu from '$lib/Model_Contextmenu.svelte';
	import Ollama_Model_Details from '$lib/Ollama_Model_Details.svelte';
	import {format_gigabytes} from '$lib/format_helpers.js';

	interface Props {
		model: Model;
		attrs?: SvelteHTMLElements['span'] | undefined;
	}

	const {model, attrs}: Props = $props();

	const app = frontend_context.get();

	onMount(async () => {
		// TODO this is a bit hacky
		if (app.ollama.list_status !== 'success') {
			await app.api.ollama_list();
		}
		if (model.needs_ollama_details) {
			await app.api.ollama_show({model: model.name});
		}
	});

	const at_detail_page = $derived(page.url.pathname === `${base}/models/${model.name}`);
	const provider = $derived(app.providers.find_by_name(model.provider_name));

	// TODO get spec data mapped to model fields for the frontier providers
	// TODO add custom models/providers, show in the UI when they're in a bad state
</script>

<Model_Contextmenu tag="div" attrs={{class: 'panel p_lg', ...attrs}} {model}>
	<section class="row mb_xl3">
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
			{#if model.downloaded !== undefined}
				<div class="mb_lg">
					<small>
						{#if model.downloaded}
							{GLYPH_CHECKMARK}
						{:else}
							{GLYPH_XMARK} not
						{/if} downloaded
					</small>
				</div>
			{/if}
			{#if model.tags.length}
				<ul class="unstyled display_flex gap_xs">
					{#each model.tags as tag (tag)}
						<small class="chip font_weight_400">{tag}</small>
					{/each}
				</ul>
			{/if}
		</div>
	</section>

	{#if model.provider_name === 'ollama'}
		<Ollama_Model_Details {model} onshow={() => app.api.ollama_show({model: model.name})}>
			{#snippet header()}{/snippet}
		</Ollama_Model_Details>
	{:else}
		<aside class="mt_xl3">
			⚠️ This information is incomplete and may be incorrect or outdated.
		</aside>
		<section class="display_flex gap_xs">
			<button
				type="button"
				class="color_d"
				onclick={() => app.chats.add(undefined, true).add_tape(model)}
			>
				<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> create a new chat
			</button>
		</section>
		<section>
			<div>
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
						{format_gigabytes(model.filesize)}
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

				{#if model.ollama_list_response_item?.details}
					{#if model.ollama_list_response_item.details.format}
						<div>
							<strong>format:</strong>
							{model.ollama_list_response_item.details.format}
						</div>
					{/if}
					{#if model.ollama_list_response_item.details.quantization_level}
						<div>
							<strong>quantization:</strong>
							{model.ollama_list_response_item.details.quantization_level}
						</div>
					{/if}
					{#if model.ollama_list_response_item.details.families.length}
						<div>
							<strong>families:</strong>
							{model.ollama_list_response_item.details.families.join(', ')}
						</div>
					{/if}
				{/if}
			</div>

			{#if model.cost_input || model.cost_output}
				<section>
					<h3>pricing</h3>
					{#if model.cost_input}
						<div><strong>input:</strong> ${model.cost_input.toFixed(2)} / 1M tokens</div>
					{/if}
					{#if model.cost_output}
						<div><strong>output:</strong> ${model.cost_output.toFixed(2)} / 1M tokens</div>
					{/if}
				</section>
			{/if}
		</section>
	{/if}
</Model_Contextmenu>

<style>
	.glyph_container {
		display: flex;
		align-items: center;
		justify-content: center;
		min-width: var(--icon_size_xl);
		line-height: 1;
	}
</style>
