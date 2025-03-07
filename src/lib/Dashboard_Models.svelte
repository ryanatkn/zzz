<script lang="ts">
	import {GLYPH_MODEL} from '$lib/glyphs.js';
	import Model_Summary from '$lib/Model_Summary.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	// TODO BLOCK link the providers below to a page per provider (lookup from provider_default/context)

	// TODO add search/filtering
</script>

<div class="p_lg">
	<h1><Glyph_Icon icon={GLYPH_MODEL} /> models</h1>
	<div class="models_grid">
		{#each zzz.models.items as model (model)}
			<Model_Summary {model} />
		{/each}
	</div>
</div>

<style>
	.models_grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(var(--width_sm), 1fr));
		gap: var(--space_lg);
		width: 100%;
		padding: var(--space_md);
	}
</style>
