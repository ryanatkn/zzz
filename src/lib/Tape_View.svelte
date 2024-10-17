<script lang="ts">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';

	import Tape_Info from '$lib/Tape_Info.svelte';
	import Tape_Summary from '$lib/Tape_Summary.svelte';
	import type {Agent} from '$lib/agent.svelte.js';
	import type {Tape, Tape_History_Item} from './tape.svelte.js';

	interface Props {
		agent: Agent;
		// TODO more efficient data structures, reactive source prompt_responses
		tape: Tape;
	}

	const {agent, tape}: Props = $props();

	let show_editor = $state(false);

	// TODO refactor
	let view_with: 'summary' | 'info' = $state('summary');

	// TODO hardcoded to one history item
	const history_item = $derived(tape.history[0] as Tape_History_Item | undefined);
	const prompt_request = $derived(history_item?.request);
	const prompt_response = $derived(history_item?.response);

	// TODO hacky
	const content = $derived(
		prompt_response
			? prompt_response.data.type === 'claude'
				? prompt_response.data.value.content
						.map((c) => (c.type === 'text' ? c.text : c.name))
						.join('\n\n')
				: prompt_response.data.type === 'gpt'
					? prompt_response.data.value.content
					: prompt_response.data.value.text
			: undefined,
	);
</script>

<div class="prompt_response_view" use:contextmenu_action={contextmenu_entries}>
	{#if view_with === 'summary'}
		<Tape_Summary {agent} {tape} />
	{:else}
		<Tape_Info {agent} {tape} />
	{/if}
</div>

{#if show_editor}
	<Dialog onclose={() => (show_editor = false)}>
		<!-- TODO expand width, might need to change `Dialog` -->
		<div class="bg p_md radius_sm width_md">
			<!-- TODO should this be a `Prompt_Response_Editor`? -->
			<Tape_Info {agent} {tape} />
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
	{#if prompt_request}
		<Contextmenu_Entry run={() => void navigator.clipboard.writeText(prompt_request.text)}>
			{#snippet icon()}📋{/snippet}
			<span>Copy prompt text ({prompt_request.text.length} chars)</span>
		</Contextmenu_Entry>
	{/if}
	<Contextmenu_Submenu>
		{#snippet icon()}>{/snippet}
		View prompt response with
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
