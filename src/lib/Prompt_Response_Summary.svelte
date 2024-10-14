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
	{#if prompt_response.data.type === 'anthropic'}
		{#each prompt_response.data.value.content as item (item)}
			<li class="content-item">
				{#if item.type === 'text'}
					{item.text}
				{:else if item.type === 'tool_use'}
					used tool {item.name} - {item.input} - {item.id}
				{/if}
			</li>
		{/each}
	{/if}
</ul>
