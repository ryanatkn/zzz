<script lang="ts">
	import Completion_Thread_View from '$lib/Completion_Thread_View.svelte';
	import type {Agent} from '$lib/agent.svelte.js';
	import type {Completion_Thread} from '$lib/completion_thread.svelte.js';

	interface Props {
		agent: Agent;
		tape: Completion_Thread;
	}

	const {agent, tape}: Props = $props();

	// TODO BLOCK multiple tapes?
</script>

<ul class="unstyled py_lg">
	{#each tape.history as history_item (history_item)}
		<li class="p_md">
			<Completion_Thread_View {agent} {tape} />
		</li>
	{/each}
</ul>
