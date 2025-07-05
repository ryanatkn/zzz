<script lang="ts">
	import {slide} from 'svelte/transition';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import type {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import type {Uuid} from '$lib/zod_helpers.js';
	import {format_time} from '$lib/time_helpers.js';

	interface Props {
		editor_state: Diskfile_Editor_State;
		onselectentry: (entry_id: Uuid) => void;
		attrs?: SvelteHTMLElements['menu'] | undefined;
	}

	const {editor_state, onselectentry, attrs}: Props = $props();
</script>

<div>
	<small class="px_sm display_flex justify_content_space_between mb_sm">
		<Confirm_Button
			onconfirm={() => editor_state.clear_history()}
			position="right"
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

	<menu {...attrs} class="unstyled {attrs?.class ?? 'max_height_sm'}">
		{#each editor_state.content_history as entry (entry.id)}
			{@const selected = entry.id === editor_state.selected_history_entry_id}
			{@const content_matches = editor_state.content_matching_entry_ids.includes(entry.id)}
			<button
				transition:slide
				type="button"
				class="listitem compact"
				class:selected
				class:content_matches
				class:plain={!selected && !content_matches}
				onclick={() => onselectentry(entry.id)}
				title={entry.label}
			>
				<span>
					<span>{format_time(new Date(entry.created))}</span>
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

	.listitem.compact {
		padding: var(--space_xs2) var(--space_xs);
		font-size: var(--font_size_sm);
		display: flex;
		justify-content: space-between;
		align-items: center;
		min-height: 0;
	}

	/* TODO this would be correct but we need an opaque bg, Moss needs the feature */
	/* button.selected {
		position: sticky;
		top: 0;
		bottom: 0;
	} */
</style>
