<script lang="ts">
	import type {Provider} from '$lib/provider.svelte.js';
	import type {
		Completion_Thread,
		Completion_Thread_History_Item,
	} from '$lib/completion_thread.svelte.js';

	interface Props {
		provider: Provider;
		completion_thread: Completion_Thread;
	}

	const {provider, completion_thread}: Props = $props();

	// TODO hardcoded to one history item
	const history_item = $derived(
		completion_thread.history[0] as Completion_Thread_History_Item | undefined,
	);
	const completion_request = $derived(history_item?.completion_request);
	const completion_response = $derived(history_item?.completion_response);
</script>

<p>{completion_thread.history.length} history items</p>
{#if completion_request}
	<pre>{completion_request.prompt}</pre>
{/if}
<h3>response from {provider.title} (@{provider.name})</h3>
<pre>{JSON.stringify(completion_response, null, '\t')}</pre>
