<script lang="ts">
	import type {Provider_Name} from '$lib/provider_types.js';

	import Capability_Provider_Ollama from '$lib/Capability_Provider_Ollama.svelte';
	import Capability_Provider_Api from '$lib/Capability_Provider_Api.svelte';

	const {
		provider_name,
	}: {
		provider_name: Provider_Name;
	} = $props();
</script>

{#if provider_name === 'ollama'}
	<Capability_Provider_Ollama />
{:else}
	<Capability_Provider_Api {provider_name} />
{/if}
