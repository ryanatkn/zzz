<script lang="ts">
	import Prompt_Response_View from '$lib/Prompt_Response_View.svelte';
	import type {Receive_Prompt_Message} from '$lib/zzz_message.js';
	import type {Agent} from '$lib/agent.svelte.js';

	interface Props {
		agent: Agent;
		prompt_responses: Receive_Prompt_Message[];
	}

	const {agent, prompt_responses}: Props = $props();

	const responses = Array.from(prompt_responses).filter((r) => r.agent_name === agent.name);
</script>

<ul class="unstyled">
	{#each responses as prompt_response (prompt_response)}
		<li>
			<Prompt_Response_View {agent} {prompt_response} />
		</li>
	{/each}
</ul>
