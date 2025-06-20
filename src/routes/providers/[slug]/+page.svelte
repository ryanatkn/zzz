<script lang="ts">
	import Alert from '@ryanatkn/fuz/Alert.svelte';
	import {page} from '$app/state';

	import Provider_Detail from '$lib/Provider_Detail.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';

	const app = frontend_context.get();

	const provider = $derived(app.providers.find_by_name(page.params.slug));
</script>

<div class="p_sm">
	{#if provider}
		<Provider_Detail {provider} />
	{:else}
		<Alert status="error">
			no provider found with name "{page.params.slug}"
		</Alert>
	{/if}
</div>
