<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	import Model_Link from '$lib/Model_Link.svelte';
	import Contextmenu_Model from '$lib/Contextmenu_Model.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import type {Model} from '$lib/model.svelte.js';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_DOWNLOAD} from '$lib/glyphs.js';
	import {format_gigabytes} from '$lib/format_helpers.js';

	interface Props {
		model: Model;
		omit_provider?: boolean | undefined;
		attrs?: SvelteHTMLElements['div'] | undefined;
	}

	const {model, omit_provider, attrs}: Props = $props();

	const provider = $derived(model.app.providers.find_by_name(model.provider_name));

	// TODO maybe rename to Model_Listitem, particularly if we add a `Model_List` for the parent usage
</script>

<Contextmenu_Model {model}>
	<div {...attrs} class="panel p_lg {attrs?.class}">
		<div class="font_size_xl mb_lg">
			<Model_Link {model} icon />
		</div>
		{#if !omit_provider}
			<div class="mb_lg">
				<Provider_Link {provider} icon="glyph" show_name />
			</div>
		{/if}

		{#if model.tags.length}
			<ul class="unstyled display_flex flex_wrap gap_xs mb_md mt_sm">
				{#each model.tags as tag (tag)}
					<small class="chip font_weight_400">{tag}</small>
				{/each}
			</ul>
		{/if}

		{#if model.downloaded === false}
			{#if model.provider_name === 'ollama' && !model.downloaded}
				<button type="button" class="plain compact" onclick={() => model.navigate_to_download()}>
					<Glyph glyph={GLYPH_DOWNLOAD} attrs={{class: 'mr_xs2'}} /> download
				</button>
			{/if}
		{/if}

		<div class="specs_grid">
			{#if model.context_window}
				<div class="spec_item">
					<span class="spec_label">context:</span>
					<span>{model.context_window.toLocaleString()} tokens</span>
				</div>
			{/if}
			{#if model.parameter_count}
				<div class="spec_item">
					<span class="spec_label">parameters:</span>
					<span>{model.parameter_count.toLocaleString()}B</span>
				</div>
			{/if}
			{#if model.filesize}
				<div class="spec_item">
					<span class="spec_label">size:</span>
					<span>{format_gigabytes(model.filesize)}</span>
				</div>
			{/if}
		</div>
	</div>
</Contextmenu_Model>

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
		font-size: var(--font_size_sm);
	}
	.spec_label {
		color: var(--color_text_2);
		font-weight: 600;
	}
</style>
