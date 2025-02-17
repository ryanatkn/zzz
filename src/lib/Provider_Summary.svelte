<script lang="ts">
	// import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import type {Provider} from '$lib/provider.svelte.js';
	import Completion_Threads_List from '$lib/Completion_Threads_List.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		// TODO more efficient data structures, reactive source providers
		provider: Provider;
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
	<div>
		<!--<span class="size_xl">{provider.icon}</span> -->
		<select bind:value={provider.selected_model_name}>
			{#each Object.values(provider.models) as model}
				<option value={model.name}>{model.name}</option>
			{/each}
		</select>
	</div>
	{#if completion_thread}
		<Completion_Threads_List {provider} {completion_thread} />
		<!-- {:else}
		<Pending_Animation /> -->
	{/if}
</div>
