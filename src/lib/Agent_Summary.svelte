<script lang="ts">
	import type {Agent} from '$lib/agent.svelte.js';
	import Prompt_Responses_List from '$lib/Prompt_Responses_List.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		// TODO more efficient data structures, reactive source agents
		agent: Agent;
	}

	const {agent}: Props = $props();

	const zzz = zzz_context.get();
</script>

<div class="flex_1">
	<!-- TODO instead of `prompt_responses`, a higher-level abstraction like a conversation -->
	<div><span class="size_xl">{agent.icon}</span> {agent.title}</div>
	<div>{agent.model}</div>
	<Prompt_Responses_List {agent} prompt_responses={zzz.prompt_responses} />
</div>
