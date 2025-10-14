<script lang="ts">
	import Action_List from '$lib/Action_List.svelte';
	import Action_Detail from '$lib/Action_Detail.svelte';
	import Dashboard_Header from '$lib/Dashboard_Header.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_LOG} from '$lib/glyphs.js';
	import type {Action} from '$lib/action.svelte.js';
	import {app_context} from '$lib/app.svelte.js';
	import Time_Widget from '$lib/Time_Widget.svelte';
	import {random_item} from '@ryanatkn/belt/random.js';

	const app = app_context.get();

	const {actions} = $derived(app);

	// TODO could potentially be removed from the collection by some external process,
	// so having this state be component-local solves some problems but not all
	let selected_action: Action | null = $state(null);
</script>

<div class="column p_lg height_100">
	<Dashboard_Header>
		{#snippet header()}
			<h1><Glyph glyph={GLYPH_LOG} /> system actions</h1>
		{/snippet}
		<Time_Widget value={app.time.now} />
	</Dashboard_Header>
	<p class="width_upto_md">
		This page shows the actions that have happened behind the scenes. It's a work in progress and
		not too useful yet. The idea is to make the system visible, auditable, and manipulable.
	</p>
	<p>
		<button
			type="button"
			class="compact"
			onclick={() => {
				actions.items.clear();
				selected_action = null;
			}}
			disabled={!actions.items.size}
		>
			clear action history
		</button>
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

		<div class="panel p_md overflow_auto height_100">
			{#if selected_action}
				<Action_Detail action={selected_action} />
			{:else if actions.items.size > 0}
				<div class="box height_100">
					<p>
						select an action from the list or <button
							type="button"
							class="inline color_f"
							onclick={() => {
								selected_action = random_item(actions.items.values);
							}}>go fish</button
						> to view its details
					</p>
				</div>
			{:else}
				<div class="box height_100">
					<p>
						no actions yet, <button
							type="button"
							class="inline color_d"
							onclick={() => {
								app.api.toggle_main_menu();
							}}>do something?</button
						>?
					</p>
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
