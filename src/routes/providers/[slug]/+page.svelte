<script lang="ts">
	import Alert from '@ryanatkn/fuz/Alert.svelte';
	import {page} from '$app/state';

	import Provider_Detail from '$lib/Provider_Detail.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	const provider = $derived(zzz.providers.find_by_name(page.params.slug));
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
