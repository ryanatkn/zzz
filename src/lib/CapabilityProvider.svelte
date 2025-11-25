<script lang="ts">
	import type {ProviderName} from '$lib/provider_types.js';

	import CapabilityProviderOllama from '$lib/CapabilityProviderOllama.svelte';
	import CapabilityProviderApi from '$lib/CapabilityProviderApi.svelte';

	const {
		provider_name,
	}: {
		provider_name: ProviderName;
	} = $props();
</script>

{#if provider_name === 'ollama'}
	<CapabilityProviderOllama />
{:else}
	<CapabilityProviderApi {provider_name} />
{/if}
