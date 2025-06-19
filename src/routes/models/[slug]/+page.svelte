<script lang="ts">
	import Alert from '@ryanatkn/fuz/Alert.svelte';
	import {page} from '$app/state';

	import Model_Detail from '$lib/Model_Detail.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';

	const app = frontend_context.get();

	const model = $derived(app.models.find_by_name(page.params.slug));
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
