<script lang="ts">
	import type {Agent} from '$lib/agent.svelte.js';
	import Prompt_Responses_List from '$lib/Prompt_Responses_List.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		agent: Agent;
		classes?: string;
	}

	const {agent, classes = ''}: Props = $props();

	const zzz = zzz_context.get();
</script>

<div class="flex_1 {classes}">
	<!-- TODO pass a zap? -->
	<!-- <div class="size_xl">{agent.icon}</div> -->
	<div>{agent.title}</div>
	<div>{agent.model}</div>
	<Prompt_Responses_List {agent} prompt_responses={zzz.prompt_responses} />
</div>
<pre>{JSON.stringify(agent.toJSON(), null, '\t')}</pre>
