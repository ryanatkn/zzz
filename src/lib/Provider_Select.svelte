<script lang="ts">
	import type {Provider} from '$lib/provider.svelte.js';

	interface Props {
		providers: Array<Provider>; // TODO fallback to get from context?
		selected_provider: Provider; // TODO fallback to get from context?
	}

	let {providers, selected_provider = $bindable()}: Props = $props();

	// TODO BLOCK currently unused but I assume I'll want something like this
</script>

<div class="row">
	<select bind:value={selected_provider}>
		{#each providers as provider (provider)}
			<option value={provider}>{provider.title}</option>
		{/each}
	</select>
</div>
