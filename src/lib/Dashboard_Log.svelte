<script lang="ts">
	import Action_List from '$lib/Action_List.svelte';
	import Action_Detail from '$lib/Action_Detail.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_LOG} from '$lib/glyphs.js';
	import type {Action} from '$lib/action.svelte.js';

	let selected_action: Action | null = $state(null);
</script>

<div class="column p_lg h_100">
	<h1><Glyph icon={GLYPH_LOG} /> log</h1>

	<div
		class="flex_1 grid mt_md overflow_hidden"
		style:grid-template-columns="320px 1fr"
		style:gap="var(--space_md)"
	>
		<div class="overflow_auto border_right">
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
				<div class="flex align_items_center justify_content_center h_100">
					<p>Select a action from the list to view its details</p>
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
