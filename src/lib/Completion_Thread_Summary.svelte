<script lang="ts">
	import {unreachable} from '@ryanatkn/belt/error.js';

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

{#if completion_request}
	<p>@user: {completion_request.prompt} ({completion_thread.history.length} history items)</p>
{/if}
{#if completion_response}
	<p>
		@{provider.title}: {#if completion_response.data.type === 'claude'}
			{#each completion_response.data.value.content as item (item)}
				{#if item.type === 'text'}
					{item.text}
				{:else if item.type === 'tool_use'}
					used tool {item.name} - {item.input} - {item.id}
				{/if}
			{/each}
		{:else if completion_response.data.type === 'chatgpt'}
			{#each completion_response.data.value.choices as choice (choice)}
				<!-- [{choice.message.role}] -->
				{choice.message.content}
			{/each}
		{:else if completion_response.data.type === 'gemini'}
			{completion_response.data.value.text}
		{:else}
			{unreachable(completion_response.data)}
		{/if}
	</p>
{/if}
