<script lang="ts">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';
	import {slide} from 'svelte/transition';

	import Payload_Info from '$lib/Payload_Info.svelte';
	import Payload_Summary from '$lib/Payload_Summary.svelte';
	import type {Payload} from '$lib/payload_types.js';

	interface Props {
		payload: Payload;
	}

	const {payload}: Props = $props();

	let show_more = $state(false);

	// TODO BLOCK refactor, maybe delete?

	let view_with: 'summary' | 'info' = $state('summary');

	const Payload_View_Component = $derived(view_with === 'summary' ? Payload_Summary : Payload_Info);
</script>

.
<div class="payload_view" use:contextmenu_action={contextmenu_entries}>
	{#key Payload_View_Component}
		<div transition:slide>
			<Payload_View_Component {payload} />
		</div>
	{/key}
</div>

{#if show_more}
	<Dialog onclose={() => (show_more = false)}>
		<div class="pane p_md width_md mx_auto">
			<!-- TODO should this be a `Payload_Editor`? -->
			<Payload_Info {payload} />
			<button type="button" onclick={() => (show_more = false)}>close</button>
		</div>
	</Dialog>
{/if}

{#snippet contextmenu_entries()}
	<!-- TODO maybe show disabled? -->
	<Contextmenu_Entry run={() => (show_more = true)}>
		{#snippet icon()}⚡{/snippet}
		<span>View payload details</span>
	</Contextmenu_Entry>
	<Contextmenu_Submenu>
		{#snippet icon()}&gt;{/snippet}
		View payload with
		{#snippet menu()}
			<!-- TODO `disabled` property to the entry -->
			<Contextmenu_Entry run={() => (view_with = 'summary')}>
				{#snippet icon()}{#if view_with === 'summary'}&gt;{/if}{/snippet}
				<span>summary</span>
			</Contextmenu_Entry>
			<Contextmenu_Entry run={() => (view_with = 'info')}>
				{#snippet icon()}{#if view_with === 'info'}&gt;{/if}{/snippet}
				<span>info</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}
