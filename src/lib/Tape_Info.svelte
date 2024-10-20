<script lang="ts">
	import type {Agent} from '$lib/agent.svelte.js';
	import type {Tape, Tape_History_Item} from '$lib/tape.svelte.js';

	interface Props {
		agent: Agent;
		tape: Tape;
	}

	const {agent, tape}: Props = $props();

	// TODO hardcoded to one history item
	const history_item = $derived(tape.history[0] as Tape_History_Item | undefined);
	const prompt_request = $derived(history_item?.request);
	const prompt_response = $derived(history_item?.response);
</script>

<p>{tape.history.length} history items</p>
{#if prompt_request}
	<pre>{prompt_request.text}</pre>
{/if}
<h3>response from {agent.title} (@{agent.name})</h3>
<pre>{JSON.stringify(prompt_response, null, '\t')}</pre>
