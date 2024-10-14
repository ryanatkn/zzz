<script lang="ts">
	import type {SvelteMap} from 'svelte/reactivity';

	import Prompt_Response_View from '$lib/Prompt_Response_View.svelte';
	import type {Receive_Prompt_Message} from '$lib/zzz_message.js';
	import type {Agent} from '$lib/agent.svelte.js';

	interface Props {
		agent: Agent;
		prompt_responses: SvelteMap<string, Receive_Prompt_Message>;
	}

	const {agent, prompt_responses}: Props = $props();
</script>

<ul class="unstyled">
	{#each prompt_responses.values() as prompt_response (prompt_response)}
		<li>
			<Prompt_Response_View {agent} {prompt_response} />
		</li>
	{/each}
</ul>
