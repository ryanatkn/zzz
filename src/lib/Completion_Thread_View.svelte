<script lang="ts">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';

	import Completion_Thread_Info from '$lib/Completion_Thread_Info.svelte';
	import Completion_Thread_Summary from '$lib/Completion_Thread_Summary.svelte';
	import type {Provider} from '$lib/provider.svelte.js';
	import type {
		Completion_Thread,
		Completion_Thread_History_Item,
	} from '$lib/completion_thread.svelte.js';
	import {as_unified_response, to_completion_response_text} from '$lib/response_helpers.js';

	interface Props {
		provider: Provider;
		// TODO more efficient data structures, reactive source completion_responses
		completion_thread: Completion_Thread;
	}

	const {provider, completion_thread}: Props = $props();

	let show_editor = $state(false);

	// TODO refactor
	let view_with: 'summary' | 'info' = $state('summary');

	// TODO hardcoded to one history item
	const history_item = $derived(
		completion_thread.history[0] as Completion_Thread_History_Item | undefined,
	);
	const completion_request = $derived(history_item?.completion_request);
	const completion_response = $derived(history_item?.completion_response);

	// Use $derived to properly calculate content when completion_response changes
	const content = $derived(
		completion_response
			? to_completion_response_text(as_unified_response(completion_response))
			: undefined,
	);
</script>

<div class="completion_response_view" use:contextmenu_action={contextmenu_entries}>
	{#if view_with === 'summary'}
		<Completion_Thread_Summary {provider} {completion_thread} />
	{:else}
		<Completion_Thread_Info {provider} {completion_thread} />
	{/if}
</div>

{#if show_editor}
	<Dialog onclose={() => (show_editor = false)}>
		<!-- TODO expand width, might need to change `Dialog` -->
		<div class="bg p_md radius_sm width_md">
			<!-- TODO should this be a `Prompt_Response_Editor`? -->
			<Completion_Thread_Info {provider} {completion_thread} />
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
	{#if completion_request}
		<Contextmenu_Entry run={() => void navigator.clipboard.writeText(completion_request.prompt)}>
			{#snippet icon()}📋{/snippet}
			<span>Copy prompt text ({completion_request.prompt.length} chars)</span>
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
