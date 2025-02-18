<script lang="ts">
	import type {Provider_Json} from '$lib/provider.svelte.js';
	import {default_providers} from '$lib/config.js';

	interface Props {
		providers?: Array<Provider_Json>;
		selected_provider: Provider_Json; // TODO get from context?
	}

	let {providers = default_providers, selected_provider = $bindable()}: Props = $props();

	// TODO currently unused but I assume I'll want something like this
</script>

<div class="row">
	<select bind:value={selected_provider}>
		{#each providers as provider (provider)}
			<option value={provider}>{provider.title}</option>
		{/each}
	</select>
</div>
