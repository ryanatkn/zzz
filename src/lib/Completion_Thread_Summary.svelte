<script lang="ts">
	import {unreachable} from '@ryanatkn/belt/error.js';

	import type {Provider} from '$lib/provider.svelte.js';
	import type {
		Completion_Thread,
		Completion_Thread_History_Item,
	} from '$lib/completion_thread.svelte.js';
	import {ensure_valid_response} from '$lib/completion.js';

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

	// Ensure the completion response is valid
	const validated_response = $derived(
		completion_response ? ensure_valid_response(completion_response) : null,
	);
</script>

{#if completion_request}
	<p>@user: {completion_request.prompt}</p>
	<!-- ({completion_thread.history.length} history items) -->
{/if}
{#if validated_response}
	<div class="mb_sm">
		@{provider.title}: {#if validated_response.data.type === 'ollama'}
			{validated_response.data.value.message.content}
			{#if validated_response.data.value.message.tool_calls}
				{#each validated_response.data.value.message.tool_calls as item (item)}
					<div>
						used tool {item.function.name} -
						<pre>{JSON.stringify(item.function.arguments, null, '\t')}</pre>
					</div>
				{/each}
			{/if}
		{:else if validated_response.data.type === 'claude'}
			{#each validated_response.data.value.content as item (item)}
				{#if item.type === 'text'}
					{item.text}
				{:else if item.type === 'tool_use'}
					used tool {item.name} - {item.input} - {item.id}
				{/if}
			{/each}
		{:else if validated_response.data.type === 'chatgpt'}
			{#each validated_response.data.value.choices as choice (choice)}
				<!-- [{choice.message.role}] -->
				{choice.message.content}
			{/each}
		{:else if validated_response.data.type === 'gemini'}
			{validated_response.data.value.text}
		{:else}
			{unreachable(validated_response.data)}
		{/if}
	</div>
{:else}
	<div class="mb_sm">No valid response data available</div>
{/if}
