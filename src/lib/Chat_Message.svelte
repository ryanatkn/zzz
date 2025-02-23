<script lang="ts">
	import type {Chat_Message} from '$lib/chat.svelte.js';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	interface Props {
		message: Chat_Message;
	}

	const {message}: Props = $props();

	const {response} = $derived(message);

	// TODO hacky
	const response_content = $derived(
		response
			? response.data.type === 'ollama'
				? response.data.value.message.content
				: response.data.type === 'claude'
					? response.data.value.content
							.map((c) => (c.type === 'text' ? c.text : c.name))
							.join('\n\n')
					: response.data.type === 'chatgpt'
						? response.data.value.choices[0].message.content
						: response.data.value.text
			: undefined,
	);
</script>

<div class="message">
	<div class="request">@me: {message.text}</div>
	<div class="response">
		@model: {#if response}{response_content}{:else}<Pending_Animation />{/if}
	</div>
</div>

<!-- {#if show_editor}
	<Dialog onclose={() => (show_editor = false)}> -->
<!-- TODO expand width, might need to change `Dialog` -->
<!-- <div class="bg p_md radius_sm width_md"> -->
<!-- TODO should this be a `Prompt_Response_Editor`? -->
<!-- <Completion_Thread_Info {provider} {completion_thread} />
			<button type="button" onclick={() => (show_editor = false)}>close</button>
		</div>
	</Dialog>
{/if} -->

<!-- {#snippet contextmenu_entries()} -->
<!-- TODO maybe show disabled? -->
<!-- {#if content}
		<Contextmenu_Entry run={() => void navigator.clipboard.writeText(content)}>
			{#snippet icon()}📋{/snippet}
			<span>Copy response text ({content.length} chars)</span>
		</Contextmenu_Entry>
	{/if}
	{#if completion_request}
		<Contextmenu_Entry run={() => void navigator.clipboard.writeText(completion_request.prompt)}>
			{#snippet icon()}📋{/snippet}
			<span>Copy prompt text ({completion_request.prompt.length} chars)</span>
		</Contextmenu_Entry>
	{/if}
	<Contextmenu_Submenu>
		{#snippet icon()}>{/snippet}
		View prompt response with
		{#snippet menu()} -->
<!-- TODO `disabled` property to the entry -->
<!-- <Contextmenu_Entry run={() => (view_with = 'summary')}>
				{#snippet icon()}{#if view_with === 'summary'}{'>'}{/if}{/snippet}
				<span>Summary</span>
			</Contextmenu_Entry>
			<Contextmenu_Entry run={() => (view_with = 'info')}>
				{#snippet icon()}{#if view_with === 'info'}{'>'}{/if}{/snippet}
				<span>Info</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet} -->
