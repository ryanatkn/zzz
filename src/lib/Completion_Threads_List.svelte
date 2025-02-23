<script lang="ts">
	import Completion_Thread_View from '$lib/Completion_Thread_View.svelte';
	import type {Provider} from '$lib/provider.svelte.js';
	import type {Completion_Thread} from '$lib/completion_thread.svelte.js';

	interface Props {
		provider: Provider;
		completion_thread: Completion_Thread;
	}

	const {provider, completion_thread}: Props = $props();

	// TODO BLOCK multiple completion_threads? delete all of this?
</script>

<ul class="unstyled py_lg">
	{#each completion_thread.history as history_item (history_item)}
		<li class="p_md">
			<Completion_Thread_View {provider} {completion_thread} />
		</li>
	{/each}
</ul>
