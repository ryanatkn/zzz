<script lang="ts">
	import {slide} from 'svelte/transition';
	import {format} from 'date-fns';

	import {FILE_TIME_FORMAT} from '$lib/cell_helpers.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import type {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import type {Uuid} from '$lib/zod_helpers.js';

	interface Props {
		editor_state: Diskfile_Editor_State;
		on_entry_select: (entry_id: Uuid) => void;
	}

	const {editor_state, on_entry_select}: Props = $props();
</script>

<div>
	<small class="px_sm flex justify_content_space_between mb_sm">
		<Confirm_Button
			onconfirm={() => editor_state.clear_history()}
			attrs={{
				class: 'plain compact',
				disabled: !editor_state.can_clear_history,
				title: editor_state.can_clear_history
					? 'Clear history entries except the current disk state'
					: 'No history entries to clear',
			}}
		>
			clear history
		</Confirm_Button>

		<Confirm_Button
			onconfirm={() => {
				editor_state.clear_unsaved_edits();
			}}
			attrs={{
				class: 'plain compact',
				disabled: !editor_state.can_clear_unsaved_edits,
				title: editor_state.can_clear_unsaved_edits
					? 'Remove all unsaved edit entries from history'
					: 'No unsaved edits to clear',
			}}
		>
			clear unsaved edits
		</Confirm_Button>
	</small>

	<menu class="unstyled flex flex_column">
		{#each editor_state.content_history as entry (entry.id)}
			{@const selected = entry.id === editor_state.selected_history_entry_id}
			{@const content_matches = editor_state.content_matching_entry_ids.includes(entry.id)}
			<button
				transition:slide
				type="button"
				class="button_list_item compact"
				class:selected
				class:content_matches
				class:plain={!selected && !content_matches}
				onclick={() => on_entry_select(entry.id)}
				title={entry.label}
			>
				<span>
					<span>{format(new Date(entry.created), FILE_TIME_FORMAT)}</span>
					{#if entry.is_disk_change}
						<span class="ml_xl">from disk</span>
					{:else if entry.is_unsaved_edit}
						<span class="ml_xl">unsaved</span>
					{/if}
				</span>
				<span>{entry.content.length} chars</span>
			</button>
		{/each}
	</menu>
</div>

<style>
	.content_matches:not(.selected) {
		background-color: var(--fg_1);
	}

	.button_list_item.compact {
		padding: var(--space_xs2) var(--space_xs);
		font-size: var(--size_sm);
		display: flex;
		justify-content: space-between;
		align-items: center;
		min-height: 0;
	}
</style>
