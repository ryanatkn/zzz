<script lang="ts">
	import Alert from '@ryanatkn/fuz/Alert.svelte';
	import {page} from '$app/state';

	import {models_default} from '$lib/config.js';
	import Model_Detail from '$lib/Model_Detail.svelte';

	const model = $derived(models_default.find((p) => p.name === page.params.slug));
</script>

<main class="width_sm">
	{#if model}
		<Model_Detail {model} />
	{:else}
		<Alert status="error">
			no model found with name "{page.params.slug}"
		</Alert>
	{/if}
</main>
