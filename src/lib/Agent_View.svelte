<script lang="ts">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';
	import type {Component} from 'svelte';

	import Agent_Info from '$lib/Agent_Info.svelte';
	import Agent_Summary from '$lib/Agent_Summary.svelte';
	import type {Agent} from '$lib/agent.svelte.js';

	interface Props {
		// TODO more efficient data structures, reactive source agents
		agent: Agent;
	}

	const {agent}: Props = $props();

	let show_more = $state(false);

	// TODO lazy loading
	const components: Record<typeof view_with, Component<{agent: Agent}>> = {
		summary: Agent_Summary,
		info: Agent_Info,
	} as const;

	// TODO refactor
	let view_with: 'summary' | 'info' = $state('summary');
	const Agent_View_Component = $derived(components[view_with]);
</script>

<div class="agent_view" use:contextmenu_action={contextmenu_entries}>
	<Agent_View_Component {agent} />
</div>

{#if show_more}
	<Dialog onclose={() => (show_more = false)}>
		<!-- TODO expand width, might need to change `Dialog` -->
		<div class="bg p_md radius_sm width_md">
			<Agent_Info {agent} />
			<button type="button" onclick={() => (show_more = false)}>close</button>
		</div>
	</Dialog>
{/if}

{#snippet contextmenu_entries()}
	<!-- TODO maybe show disabled? -->
	<Contextmenu_Entry
		run={() => {
			show_more = true;
		}}
	>
		{#snippet icon()}🪄{/snippet}
		<span>{agent.title}</span>
	</Contextmenu_Entry>
	<Contextmenu_Submenu>
		{#snippet icon()}>{/snippet}
		View agent with
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

<style>
	.agent_view {
		/* TODO or should this be optional in a `classes` prop? */
		width: 100%;
	}
</style>
