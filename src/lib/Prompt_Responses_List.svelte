<script lang="ts">
	import Prompt_Response_View from '$lib/Prompt_Response_View.svelte';
	import type {Agent} from '$lib/agent.svelte.js';
	import type {Tape} from './tape.svelte.js';

	interface Props {
		agent: Agent;
		tape: Tape;
	}

	const {agent, tape}: Props = $props();
</script>

<ul class="unstyled py_lg">
	{#each tape.history as t (t)}
		<li class="p_md">
			<Prompt_Response_View {agent} prompt_response={t.response} />
		</li>
	{/each}
</ul>
