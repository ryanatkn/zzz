<script lang="ts">
	import type {Agent} from '$lib/agent.svelte.js';
	import Tapes_List from '$lib/Tapes_List.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		agent: Agent;
		classes?: string;
	}

	const {agent, classes = ''}: Props = $props();

	const zzz = zzz_context.get();

	// TODO @many hacky, need id - should be a list? or component takes a `tape`
	const tape = $derived(zzz.tapes.all.find((t) => t.agents_by_name.get(agent.name)));
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
	<div>models: {JSON.stringify(agent.models)}</div>
	{#if tape}
		<Tapes_List {agent} {tape} />
	{:else}
		<p>no tape found for {agent.name}</p>
	{/if}
</div>
<pre>{JSON.stringify(agent.toJSON(), null, '\t')}</pre>
