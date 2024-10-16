<script lang="ts">
	import type {Agent} from '$lib/agent.svelte.js';
	import Prompt_Responses_List from '$lib/Prompt_Responses_List.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		// TODO more efficient data structures, reactive source agents
		agent: Agent;
		classes?: string;
	}

	const {agent, classes = ''}: Props = $props();

	const zzz = zzz_context.get();

	// TODO @many hacky, need id - should be a list? or component takes a `tape`
	const tape = $derived(zzz.tapes.all.find((t) => t.agents_by_name.get(agent.name)));
</script>

<div class="flex_1 {classes}">
	<!-- TODO instead of `prompt_responses`, a higher-level abstraction like a conversation -->
	<div><!--<span class="size_xl">{agent.icon}</span> -->{agent.title}</div>
	<div>{agent.model}</div>
	{#if tape}
		<Prompt_Responses_List {agent} {tape} />
	{:else}
		<p>no tape found for {agent.name}</p>
	{/if}
</div>
