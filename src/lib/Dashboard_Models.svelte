<script lang="ts">
	import {GLYPH_MODEL} from '$lib/glyphs.js';
	import Model_Summary from '$lib/Model_Summary.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	// TODO add search/filtering
</script>

<div class="p_lg">
	<h1><Glyph glyph={GLYPH_MODEL} /> models</h1>
	<aside>⚠️ This information is incomplete and may be incorrect or outdated.</aside>
	<div class="models_grid">
		{#each zzz.models.ordered_by_name as model (model)}
			<Model_Summary {model} />
		{/each}
	</div>
</div>

<style>
	.models_grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space_lg);
		width: 100%;
	}
</style>
