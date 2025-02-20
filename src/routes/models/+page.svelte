<script lang="ts">
	import {models_default} from '$lib/config.js';
	import Model_Summary from '$lib/Model_Summary.svelte';

	// TODO BLOCK link the providers below to a page per provider (lookup from provider_default/context)
</script>

<div class="p_lg">
	<h1>Models</h1>
	<div class="models_grid">
		{#each models_default as model}
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
		padding: var(--space_md);
	}
</style>
