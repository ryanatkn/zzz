<script lang="ts">
	import Alert from '@ryanatkn/fuz/Alert.svelte';
	import {page} from '$app/state';

	import Model_Detail from '$lib/Model_Detail.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	const model = $derived(zzz.models.items.find((p) => p.name === page.params.slug));
</script>

<div class="p_sm">
	{#if model}
		<Model_Detail {model} />
	{:else}
		<Alert status="error">
			no model found with name "{page.params.slug}"
		</Alert>
	{/if}
</div>
