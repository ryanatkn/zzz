<script lang="ts">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';

	import Prompt_Response_Info from '$lib/Prompt_Response_Info.svelte';
	import Prompt_Response_Summary from '$lib/Prompt_Response_Summary.svelte';
	import type {Receive_Prompt_Message} from '$lib/zzz_message.js';
	import type {Agent} from '$lib/agent.svelte.js';

	interface Props {
		agent: Agent;
		// TODO more efficient data structures, reactive source prompt_responses
		prompt_response: Receive_Prompt_Message;
	}

	const {agent, prompt_response}: Props = $props();

	let show_editor = $state(false);

	// TODO refactor
	let view_with: 'summary' | 'info' = $state('summary');

	// TODO hacky
	const content = $derived(
		prompt_response.data.type === 'anthropic'
			? prompt_response.data.value.content
					.map((c) => (c.type === 'text' ? c.text : c.name))
					.join('\n\n')
			: '',
	);
</script>

<div class="prompt_response_view" use:contextmenu_action={contextmenu_entries}>
	{#if view_with === 'summary'}
		<Prompt_Response_Summary {agent} {prompt_response} />
	{:else}
		<Prompt_Response_Info {agent} {prompt_response} />
	{/if}
</div>

{#if show_editor}
	<Dialog onclose={() => (show_editor = false)}>
		<!-- TODO expand width, might need to change `Dialog` -->
		<div class="bg p_md radius_sm width_md">
			<!-- TODO should this be a `Prompt_Response_Editor`? -->
			<Prompt_Response_Info {agent} {prompt_response} />
			<button type="button" onclick={() => (show_editor = false)}>close</button>
		</div>
	</Dialog>
{/if}

{#snippet contextmenu_entries()}
	<!-- TODO maybe show disabled? -->
	{#if content}
		<Contextmenu_Entry run={() => void navigator.clipboard.writeText(content)}>
			{#snippet icon()}📋{/snippet}
			<span>Copy response text ({content.length} chars)</span>
		</Contextmenu_Entry>
	{/if}
	<Contextmenu_Entry run={() => void navigator.clipboard.writeText(prompt_response.text)}>
		{#snippet icon()}📋{/snippet}
		<span>Copy prompt text ({prompt_response.text.length} chars)</span>
	</Contextmenu_Entry>
	<Contextmenu_Submenu>
		{#snippet icon()}>{/snippet}
		View with
		{#snippet menu()}
			<!-- TODO `disabled` property to the entry -->
			<Contextmenu_Entry run={() => (view_with = 'summary')}>
				{#snippet icon()}{#if view_with === 'summary'}{'>'}{/if}{/snippet}
				<span>Summary</span>
			</Contextmenu_Entry>
			<Contextmenu_Entry run={() => (view_with = 'info')}>
				{#snippet icon()}{#if view_with === 'info'}{'>'}{/if}{/snippet}
				<span>Info</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}
