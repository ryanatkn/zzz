<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import type {Model} from '$lib/model.svelte.js';

	interface Props {
		model: Model;
		attrs?: SvelteHTMLElements['div'];
	}

	const {model, attrs}: Props = $props();
	const provider = $derived(model.zzz.providers.find_by_name(model.provider_name));
</script>

<div {...attrs} class="panel p_lg {attrs?.class}">
	<div class="size_xl mb_lg">
		<Model_Link {model} icon="glyph" />
	</div>
	<div class="mb_lg">
		<Provider_Link {provider} icon="svg" attrs={{class: 'row gap_sm'}} />
	</div>

	{#if model.tags.length}
		<ul class="unstyled flex flex_wrap gap_xs mb_md mt_sm">
			{#each model.tags as tag (tag)}
				<span class="chip size_sm font_weight_400">{tag}</span>
			{/each}
		</ul>
	{/if}

	{#if model.downloaded === false}
		<div class="mb_sm">
			<small class="bg_e_1 px_sm radius_xs">not downloaded</small>
		</div>
	{/if}

	<div class="specs_grid">
		{#if model.context_window}
			<div class="spec_item">
				<span class="spec_label">Context:</span>
				<span>{model.context_window.toLocaleString()} tokens</span>
			</div>
		{/if}
		{#if model.parameter_count}
			<div class="spec_item">
				<span class="spec_label">Parameters:</span>
				<span>{model.parameter_count.toLocaleString()}B</span>
			</div>
		{/if}
		{#if model.filesize}
			<div class="spec_item">
				<span class="spec_label">Size:</span>
				<span>{model.filesize}GB</span>
			</div>
		{/if}
	</div>
</div>

<style>
	.specs_grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: var(--space_xs);
	}
	.spec_item {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space_xs);
		font-size: var(--size_sm);
	}
	.spec_label {
		color: var(--color_text_2);
		font-weight: 500;
	}
</style>
