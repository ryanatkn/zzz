<script lang="ts">
	import type {Receive_Prompt_Message} from '$lib/zzz_message.js';
	import type {Agent} from '$lib/agent.svelte.js';

	interface Props {
		agent: Agent;
		// TODO more efficient data structures, reactive source prompt_responses
		prompt_response: Receive_Prompt_Message;
	}

	const {agent, prompt_response}: Props = $props();
</script>

<h3>prompt</h3>
<pre>{prompt_response.text}</pre>
<h3>response from {agent.title}</h3>
<pre>{JSON.stringify(prompt_response, null, '\t')}</pre>
