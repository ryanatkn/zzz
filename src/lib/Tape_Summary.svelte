<script lang="ts">
	import type {Receive_Prompt_Message} from '$lib/zzz_message.js';
	import type {Agent} from '$lib/agent.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {unreachable} from '@ryanatkn/belt/error.js';

	interface Props {
		agent: Agent;
		// TODO more efficient data structures, reactive source prompt_responses
		prompt_response: Receive_Prompt_Message;
	}

	const {agent, prompt_response}: Props = $props();

	const zzz = zzz_context.get();

	const prompt_request = $derived(zzz.tapes.prompt_requests.get(prompt_response.request_id));
</script>

<p>@user: {prompt_request?.request.text}</p>
<p>
	@{agent.title}: {#if prompt_response.data.type === 'claude'}
		{#each prompt_response.data.value.content as item (item)}
			{#if item.type === 'text'}
				{item.text}
			{:else if item.type === 'tool_use'}
				used tool {item.name} - {item.input} - {item.id}
			{/if}
		{/each}
	{:else if prompt_response.data.type === 'gpt'}
		{prompt_response.data.value.content}
	{:else if prompt_response.data.type === 'gemini'}
		{prompt_response.data.value.text}
	{:else}
		{unreachable(prompt_response.data)}
	{/if}
</p>
