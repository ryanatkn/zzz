<script lang="ts">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';
	import {slide} from 'svelte/transition';

	import Message_Info from '$lib/Message_Info.svelte';
	import Message_Summary from '$lib/Message_Summary.svelte';
	import type {Message} from '$lib/message_types.js';

	interface Props {
		message: Message;
	}

	const {message}: Props = $props();

	let show_more = $state(false);

	// TODO refactor
	let view_with: 'summary' | 'info' = $state('summary');

	const Message_View_Component = $derived(view_with === 'summary' ? Message_Summary : Message_Info);
</script>

.
<div class="message_view" use:contextmenu_action={contextmenu_entries}>
	{#key Message_View_Component}
		<div transition:slide>
			<Message_View_Component {message} />
		</div>
	{/key}
</div>

{#if show_more}
	<Dialog onclose={() => (show_more = false)}>
		<!-- TODO expand width, might need to change `Dialog` -->
		<div class="bg p_md radius_sm width_md">
			<!-- TODO should this be a `Message_Editor`? -->
			<Message_Info {message} />
			<button type="button" onclick={() => (show_more = false)}>close</button>
		</div>
	</Dialog>
{/if}

{#snippet contextmenu_entries()}
	<!-- TODO maybe show disabled? -->
	<Contextmenu_Entry run={() => (show_more = true)}>
		{#snippet icon()}⚡{/snippet}
		<span>View message details</span>
	</Contextmenu_Entry>
	<Contextmenu_Submenu>
		{#snippet icon()}>{/snippet}
		View message with
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
