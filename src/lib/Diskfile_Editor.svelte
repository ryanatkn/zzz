<script lang="ts">
	import {format} from 'date-fns';
	import {slide} from 'svelte/transition';
	import {untrack} from 'svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Diskfile_Info from '$lib/Diskfile_Info.svelte';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Diskfile_Actions from '$lib/Diskfile_Actions.svelte';
	import {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import {FILE_TIME_FORMAT} from '$lib/cell_helpers.js';

	interface Props {
		diskfile: Diskfile;
	}

	const {diskfile}: Props = $props();
	const zzz = zzz_context.get();

	// Create editor state once and reuse it
	const editor_state = new Diskfile_Editor_State({zzz, diskfile});

	// Reference to the content editor component
	let content_editor: {focus: () => void} | undefined = $state();

	// Combined effect to handle diskfile changes and disk change detection
	$effect.pre(() => {
		// Track diskfile changes explicitly
		const diskfile_id = diskfile.id;
		const diskfile_content = diskfile.content;

		untrack(() => {
			// If the diskfile ID changed, this is a navigation to a different file
			if (editor_state.diskfile.id !== diskfile_id) {
				editor_state.update_diskfile(diskfile);
			}
			// Otherwise, if only the content changed, check for disk changes
			else if (diskfile_content !== editor_state.last_seen_disk_content) {
				// This handles the case where the file was updated outside the app
				editor_state.check_disk_changes();
			}
		});
	});
</script>

<div class="flex h_100">
	<div class="flex_1 h_100 column">
		<Content_Editor
			content={editor_state.current_content}
			onchange={(content) => {
				editor_state.current_content = content;
			}}
			placeholder={diskfile.pathname}
			show_stats
			readonly={false}
			attrs={{class: 'radius_0'}}
			bind:this={content_editor}
		/>
	</div>

	<div class="width_sm">
		<div class="mb_md p_md">
			<Diskfile_Info {diskfile} {editor_state} />
		</div>

		<div class="mb_md p_md">
			<Diskfile_Actions {diskfile} {editor_state} />
		</div>

		{#if diskfile.dependencies_count || diskfile.dependents_count}
			<div class="mt_md panel p_md">
				{#if diskfile.dependencies_count}
					<div class="mb_md">
						<h3 class="mt_0 mb_sm">
							Dependencies ({diskfile.dependencies_count})
						</h3>
						<div class="dep_list">
							{#each diskfile.dependency_ids as dependency_id (dependency_id)}
								<div class="dep_item">{zzz.diskfiles.to_relative_path(dependency_id)}</div>
							{/each}
						</div>
					</div>
				{/if}

				{#if diskfile.dependents_count}
					<div>
						<h3 class="mt_0 mb_sm">
							Dependents ({diskfile.dependents_count})
						</h3>
						<div class="dep_list">
							{#each diskfile.dependent_ids as dependent_id (dependent_id)}
								<div class="dep_item">{zzz.diskfiles.to_relative_path(dependent_id)}</div>
							{/each}
						</div>
					</div>
				{/if}
			</div>
		{/if}

		{#if editor_state.has_history}
			<div transition:slide>
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
						<!-- TODO `class:plain={!selected}` is a hack around a Moss bug -->
						<button
							transition:slide
							type="button"
							class="button_list_item compact"
							class:selected
							class:content_matches
							class:plain={!selected && !content_matches}
							onclick={() => {
								editor_state.set_content_from_history(entry.id);
								content_editor?.focus();
							}}
							title={entry.label}
						>
							<!-- TODO if they're made into cells, there's a derived property for this -->
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
		{/if}
	</div>
</div>

<style>
	.dep_list {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: var(--space_xs);
	}

	.dep_item {
		font-family: monospace;
		font-size: var(--size_sm);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		padding: var(--space_xs2);
	}

	.content_matches:not(.selected) {
		background-color: var(--fg_1);
	}
</style>
