<script lang="ts">
	import {unreachable} from '@ryanatkn/belt/error.js';

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

{#if prompt_request}
	<p>@user: {prompt_request.text} ({tape.history.length} history items)</p>
{/if}
{#if prompt_response}
	<p>
		@{agent.title}: {#if prompt_response.data.type === 'claude'}
			{#each prompt_response.data.value.content as item (item)}
				{#if item.type === 'text'}
					{item.text}
				{:else if item.type === 'tool_use'}
					used tool {item.name} - {item.input} - {item.id}
				{/if}
			{/each}
		{:else if prompt_response.data.type === 'chatgpt'}
			{#each prompt_response.data.value.choices as choice (choice)}
				<!-- [{choice.message.role}] -->
				{choice.message.content}
			{/each}
		{:else if prompt_response.data.type === 'gemini'}
			{prompt_response.data.value.text}
		{:else}
			{unreachable(prompt_response.data)}
		{/if}
	</p>
{/if}
