<script lang="ts">
	import type {Receive_Prompt_Message} from '$lib/zzz_message.js';
	import type {Agent} from '$lib/agent.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		agent: Agent;
		// TODO more efficient data structures, reactive source prompt_responses
		prompt_response: Receive_Prompt_Message;
	}

	const {agent, prompt_response}: Props = $props();

	const zzz = zzz_context.get();

	const prompt_request = $derived(zzz.tapes.prompt_requests.get(prompt_response.request_id));
</script>

<h3>prompt</h3>
<pre>{prompt_request?.request.text}</pre>
<h3>response from {agent.title} (@{agent.name})</h3>
<pre>{JSON.stringify(prompt_response, null, '\t')}</pre>
