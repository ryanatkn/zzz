<script lang="ts">
	import type {Agent} from '$lib/agent.svelte.js';
	import type {
		Completion_Thread,
		Completion_Thread_History_Item,
	} from '$lib/completion_thread.svelte.js';

	interface Props {
		agent: Agent;
		tape: Completion_Thread;
	}

	const {agent, tape}: Props = $props();

	// TODO hardcoded to one history item
	const history_item = $derived(tape.history[0] as Completion_Thread_History_Item | undefined);
	const completion_request = $derived(history_item?.completion_request);
	const completion_response = $derived(history_item?.completion_response);
</script>

<p>{tape.history.length} history items</p>
{#if completion_request}
	<pre>{completion_request.prompt}</pre>
{/if}
<h3>response from {agent.title} (@{agent.name})</h3>
<pre>{JSON.stringify(completion_response, null, '\t')}</pre>
