<script lang="ts">
	// @slop claude_sonnet_4

	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_REFRESH} from '$lib/glyphs.js';
	import type {Ollama_Model_Detail, Ollama} from '$lib/ollama.svelte.js';

	interface Props {
		model_detail: Ollama_Model_Detail;
		ollama: Ollama;
	}

	const {model_detail, ollama}: Props = $props();

	const load_model_details = async () => {
		await ollama.show_model(model_detail.model_name);
	};

	// Format model info for display
	const format_model_info = (info: Record<string, any>) => {
		const entries = Object.entries(info);
		return entries.map(([key, value]) => {
			if (typeof value === 'object' && value !== null) {
				return `${key}: ${JSON.stringify(value, null, 2)}`;
			}
			return `${key}: ${value}`;
		});
	};
</script>

{#if model_detail.show_status === 'initial'}
	<div class="display_flex gap_sm align_items_center">
		<button
			type="button"
			class="icon_button plain"
			onclick={() => load_model_details()}
			title="load model details"
		>
			<Glyph glyph={GLYPH_REFRESH} />
		</button>
		<span class="font_size_sm">click to load model details</span>
	</div>
{:else if model_detail.show_status === 'pending'}
	<div class="display_flex gap_sm align_items_center">
		<Pending_Animation />
		<span class="font_size_sm">loading model details...</span>
	</div>
{:else if model_detail.show_status === 'failure'}
	<div class="display_flex flex_column gap_sm">
		<div class="color_c font_size_sm">
			Failed to load details: {model_detail.show_error || 'unknown error'}
		</div>
		<button
			type="button"
			class="color_c icon_button plain"
			onclick={() => load_model_details()}
			title="retry loading details"
		>
			<Glyph glyph={GLYPH_REFRESH} />
		</button>
	</div>
{:else if model_detail.show_response}
	<div class="display_flex flex_column gap_md">
		<!-- Basic Info -->
		<div class="display_grid gap_sm" style:grid-template-columns="auto 1fr">
			<span class="font_weight_600">Family:</span>
			<span class="font_family_mono">{model_detail.show_response.details.family}</span>

			<span class="font_weight_600">Format:</span>
			<span class="font_family_mono">{model_detail.show_response.details.format}</span>

			<span class="font_weight_600">Parameters:</span>
			<span class="font_family_mono">
				{model_detail.show_response.details.parameter_size}
			</span>

			<span class="font_weight_600">Quantization:</span>
			<span class="font_family_mono">
				{model_detail.show_response.details.quantization_level}
			</span>

			{#if model_detail.show_response.details.parent_model}
				<span class="font_weight_600">Parent:</span>
				<span class="font_family_mono">{model_detail.show_response.details.parent_model}</span>
			{/if}
		</div>

		<!-- System Prompt -->
		{#if model_detail.show_response.system}
			<div>
				<h5 class="mt_0 mb_xs font_weight_600">System Prompt:</h5>
				<pre
					class="font_size_sm bg_2 p_sm border_radius_xs overflow_auto"
					style:max-height="200px">{model_detail.show_response.system}</pre>
			</div>
		{/if}

		<!-- Template -->
		{#if model_detail.show_response.template}
			<div>
				<h5 class="mt_0 mb_xs font_weight_600">Template:</h5>
				<pre
					class="font_size_sm bg_2 p_sm border_radius_xs overflow_auto"
					style:max-height="200px">{model_detail.show_response.template}</pre>
			</div>
		{/if}

		<!-- Model Info -->
		{#if model_detail.show_response.model_info instanceof Map && model_detail.show_response.model_info.size > 0}
			<div>
				<h5 class="mt_0 mb_xs font_weight_600">Model Info:</h5>
				<pre
					class="font_size_sm bg_2 p_sm border_radius_xs overflow_auto"
					style:max-height="300px">{format_model_info(model_detail.show_response.model_info).join(
						'\n',
					)}</pre>
			</div>
		{/if}

		<!-- License -->
		{#if model_detail.show_response.license}
			<div>
				<h5 class="mt_0 mb_xs font_weight_600">License:</h5>
				<pre
					class="font_size_sm bg_2 p_sm border_radius_xs overflow_auto"
					style:max-height="200px">{model_detail.show_response.license}</pre>
			</div>
		{/if}

		<!-- Modelfile -->
		{#if model_detail.show_response.modelfile}
			<div>
				<h5 class="mt_0 mb_xs font_weight_600">Modelfile:</h5>
				<pre
					class="font_size_sm bg_2 p_sm border_radius_xs overflow_auto"
					style:max-height="300px">{model_detail.show_response.modelfile}</pre>
			</div>
		{/if}
	</div>
{/if}
