<script lang="ts">
	import Action_List from '$lib/Action_List.svelte';
	import Action_Detail from '$lib/Action_Detail.svelte';
	import Dashboard_Header from '$lib/Dashboard_Header.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_LOG} from '$lib/glyphs.js';
	import type {Action} from '$lib/action.svelte.js';
	import {app_context} from '$lib/app.svelte.js';
	import Time_Widget from '$lib/Time_Widget.svelte';

	let selected_action: Action | null = $state(null);

	const app = app_context.get();
</script>

<div class="column p_lg h_100">
	<Dashboard_Header>
		{#snippet header()}
			<h1><Glyph glyph={GLYPH_LOG} /> system log</h1>
		{/snippet}
		<Time_Widget value={app.time.now} />
	</Dashboard_Header>
	<p>
		This page shows the actions that have happened behind the scenes. It's a work in progress and
		not too useful yet. The idea is to make the system visible and manipulable.
	</p>

	<div
		class="flex_1 display_grid overflow_hidden"
		style:grid-template-columns="320px 1fr"
		style:gap="var(--space_md)"
	>
		<div class="overflow_auto scrollbar_width_thin border_right">
			<Action_List
				limit={100}
				selected_action_id={selected_action?.id}
				onselect={(action) => {
					selected_action = action;
				}}
			/>
		</div>

		<div class="panel p_md overflow_auto h_100">
			{#if selected_action}
				<Action_Detail action={selected_action} />
			{:else}
				<div class="display_flex align_items_center justify_content_center h_100">
					<p>select an action from the list to view its details</p>
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
	.border_right {
		border-right: 1px solid var(--color_border);
	}
</style>
