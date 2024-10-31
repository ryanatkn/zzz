<script lang="ts">
	import type {Agent} from '$lib/agent.svelte.js';
	import Completion_Threads_List from '$lib/Completion_Threads_List.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		agent: Agent;
		classes?: string;
	}

	const {agent, classes = ''}: Props = $props();

	const zzz = zzz_context.get();

	// TODO @many hacky, need id - should be a list? or component takes a `completion_thread`
	const completion_thread = $derived(
		zzz.completion_threads.all.find((t) => t.agents_by_name.get(agent.name)),
	);
</script>

<div class="flex_1 {classes}">
	<!-- TODO pass a zap? -->
	<!-- <div class="size_xl">{agent.icon}</div> -->
	<div class="row">
		{agent.title}
		<select bind:value={agent.selected_model_name}>
			{#each Object.values(agent.models) as model}
				<option value={model.name}>{model.name}</option>
			{/each}
		</select>
	</div>
	{#if completion_thread}
		<Completion_Threads_List {agent} {completion_thread} />
	{:else}
		<p>no completion thread found for {agent.name}</p>
	{/if}
</div>
<pre>{JSON.stringify(agent.toJSON(), null, '\t')}</pre>
<div>models</div>
<pre>{JSON.stringify(agent.models, null, '\t')}</pre>
