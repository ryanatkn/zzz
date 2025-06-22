<script lang="ts">
	import Alert from '@ryanatkn/fuz/Alert.svelte';
	import {page} from '$app/state';
	import {BROWSER} from 'esm-env';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import Provider_Detail from '$lib/Provider_Detail.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';

	const app = frontend_context.get();

	const provider = $derived(app.providers.find_by_name(page.params.slug));

	// TODO @many consider namespacing under `/llms/`
</script>

<div class="p_sm">
	{#if provider}
		<Provider_Detail {provider} />
	{:else if BROWSER}
		<Alert status="error">
			no provider found with name "{page.params.slug}"
		</Alert>
	{:else}
		<!-- for SSR - is the animation what we want? better than nothing? -->
		<Pending_Animation running />
	{/if}
</div>
