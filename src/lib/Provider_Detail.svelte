<script lang="ts">
	import type {Provider_Json} from '$lib/provider.svelte.js';
	import Completion_Threads_List from '$lib/Completion_Threads_List.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		provider: Provider_Json;
		classes?: string;
	}

	const {provider, classes = ''}: Props = $props();

	const zzz = zzz_context.get();

	// TODO @many hacky, need id - should be a list? or component takes a `completion_thread`
	const completion_thread = $derived(
		zzz.completion_threads.all.find((t) => t.providers_by_name.get(provider.name)),
	);
</script>

<div class="flex_1 {classes}">
	<!-- TODO pass a zap? -->
	<!-- <div class="size_xl">{provider.icon}</div> -->
	<div class="row">
		{provider.title}
		<!-- <select bind:value={provider.selected_model_name}>
			{#each Object.values(provider.models) as model}
				<option value={model.name}>{model.name}</option>
			{/each}
		</select> -->
	</div>
	<!-- {#if completion_thread}
		<Completion_Threads_List {provider} {completion_thread} />
	{:else}
		<p>no completion thread found for {provider.name}</p>
	{/if} -->
</div>
<pre>{JSON.stringify(provider, null, '\t')}</pre>
<!-- <div>models</div>
<pre>{JSON.stringify(provider.models, null, '\t')}</pre> -->
