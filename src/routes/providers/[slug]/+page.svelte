<script lang="ts">
	import Alert from '@ryanatkn/fuz/Alert.svelte';
	import {page} from '$app/state';

	import {providers_default} from '$lib/config.js';
	import Provider_Detail from '$lib/Provider_Detail.svelte';

	const provider = $derived(providers_default.find((p) => p.name === page.params.slug));
</script>

<main class="width_sm">
	{#if provider}
		<Provider_Detail {provider} />
	{:else}
		<Alert status="error">
			no provider found with name "{page.params.slug}"
		</Alert>
	{/if}
</main>
