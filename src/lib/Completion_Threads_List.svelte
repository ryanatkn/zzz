<script lang="ts">
	import Completion_Thread_View from '$lib/Completion_Thread_View.svelte';
	import type {Agent} from '$lib/agent.svelte.js';
	import type {Completion_Thread} from '$lib/completion_thread.svelte.js';

	interface Props {
		agent: Agent;
		completion_thread: Completion_Thread;
	}

	const {agent, completion_thread}: Props = $props();

	// TODO BLOCK multiple completion_threads?
</script>

<ul class="unstyled py_lg">
	{#each completion_thread.history as history_item (history_item)}
		<li class="p_md">
			<Completion_Thread_View {agent} {completion_thread} />
		</li>
	{/each}
</ul>
