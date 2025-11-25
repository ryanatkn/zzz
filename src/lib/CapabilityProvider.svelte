<script lang="ts">
	import type {ProviderName} from './provider_types.js';

	import CapabilityProviderOllama from './CapabilityProviderOllama.svelte';
	import CapabilityProviderApi from './CapabilityProviderApi.svelte';

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
