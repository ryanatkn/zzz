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

<p>user: {prompt_response.text}</p>
<p>{agent.title}:</p>
<ul class="content-list">
	{#each prompt_response.data.content as item}
		<li class="content-item">
			{#if item.type === 'text'}
				{item.text}
			{:else if item.type === 'tool_use'}
				used tool {item.name} - {item.input} - {item.id}
			{/if}
		</li>
	{/each}
</ul>
