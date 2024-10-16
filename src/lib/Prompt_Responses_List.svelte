<script lang="ts">
	import Prompt_Response_View from '$lib/Prompt_Response_View.svelte';
	import type {Receive_Prompt_Message} from '$lib/zzz_message.js';
	import type {Agent} from '$lib/agent.svelte.js';

	interface Props {
		agent: Agent;
		prompt_responses: Receive_Prompt_Message[];
	}

	const {agent, prompt_responses}: Props = $props();

	const responses = $derived(
		Array.from(prompt_responses)
			.filter((r) => r.agent_name === agent.name)
			.reverse(),
	);
</script>

<ul class="unstyled py_lg">
	{#each responses as prompt_response (prompt_response)}
		<li class="p_md">
			<Prompt_Response_View {agent} {prompt_response} />
		</li>
	{/each}
</ul>
