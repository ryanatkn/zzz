<script lang="ts">
	import {slide} from 'svelte/transition';

	import type {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';

	interface Props {
		editor_state: Diskfile_Editor_State;
		on_accept_disk_changes: () => void;
		on_reject_disk_changes: () => void;
	}

	const {editor_state, on_accept_disk_changes, on_reject_disk_changes}: Props = $props();

	const file_changed_on_disk = $derived(editor_state.disk_changed);
</script>

<div class="history_panel">
	{#if file_changed_on_disk}
		<div class="disk_change_alert panel p_sm" transition:slide={{duration: 200}}>
			<div class="flex justify_content_space_between align_items_center mb_xs3">
				<strong class="color_c">File changed on disk</strong>
			</div>
		</div>
		<div class="column gap_xs2 size_sm">
			<div>The file has been modified outside of the editor.</div>
			<div class="flex gap_sm">
				<button type="button" class="compact color_b" onclick={on_accept_disk_changes}>
					accept changes
				</button>
				<button type="button" class="compact color_c" onclick={on_reject_disk_changes}>
					ignore state on disk
				</button>
			</div>
			<div>
				Accept to update your editor with the new content (your changes will be preserved in
				history). Ignore to keep your current version.
			</div>
		</div>
	{/if}
</div>

<style>
	.history_panel {
		border-top: 1px solid var(--border_color_1);
		padding-top: var(--space_xs);
	}

	.disk_change_alert {
		border-left: 3px solid var(--color_c);
		margin-bottom: var(--space_sm);
	}
</style>
