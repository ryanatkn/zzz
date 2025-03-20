<script lang="ts">
	import {untrack} from 'svelte';
	import {format} from 'date-fns';
	import {slide} from 'svelte/transition';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Diskfile_Info from '$lib/Diskfile_Info.svelte';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import Diskfile_Actions from '$lib/Diskfile_Actions.svelte';
	import {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import Diskfile_History_Panel from '$lib/Diskfile_History_Panel.svelte';

	interface Props {
		diskfile: Diskfile;
	}

	const {diskfile}: Props = $props();
	const zzz = zzz_context.get();

	// Create editor state once and reuse it
	const editor_state = new Diskfile_Editor_State({zzz, diskfile});

	// When the diskfile changes, update the editor state with the new diskfile
	$effect.pre(() => {
		// We need to track both the ID to ensure we detect all changes
		diskfile.id;

		untrack(() => {
			// Update the editor state with the new diskfile
			editor_state.update_diskfile(diskfile);
		});
	});

	// Check for disk changes when diskfile content changes
	$effect.pre(() => {
		// Watch for content changes from the diskfile
		diskfile.content;
		// Also watch for changes in our tracking state to ensure UI updates properly
		diskfile.id;
		editor_state.last_seen_disk_content;

		untrack(() => {
			// Check if file changed on disk
			editor_state.check_disk_changes();
		});
	});

	// Reference to the content editor component
	let content_editor: {focus: () => void} | undefined = $state();

	const has_history = $derived(editor_state.content_history.length > 1);
</script>

<div class="flex h_100">
	<div class="flex_1 h_100 column">
		<Content_Editor
			content={editor_state.updated_content}
			onchange={(content) => {
				editor_state.updated_content = content;
			}}
			placeholder={diskfile.pathname}
			show_stats
			readonly={false}
			attrs={{class: 'radius_0'}}
			bind:this={content_editor}
		/>

		<Diskfile_History_Panel
			{editor_state}
			on_accept_disk_changes={() => {
				editor_state.accept_disk_changes();
				content_editor?.focus();
			}}
			on_reject_disk_changes={() => {
				editor_state.reject_disk_changes();
			}}
		/>
	</div>

	<div class="width_sm">
		<div class="mb_md p_sm">
			<div class="p_xs">
				<Diskfile_Info {diskfile} {editor_state} />
			</div>
		</div>

		<Diskfile_Actions {diskfile} {editor_state} />

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

		{#if has_history}
			<div transition:slide>
				<small class="px_sm flex justify_content_space_between">
					<div>Edit History</div>
					<div>{editor_state.content_history.length} entries</div>
				</small>
				<menu class="unstyled flex flex_column_reverse mt_xs">
					{#each editor_state.content_history as entry (entry.created)}
						{@const selected = entry.content === editor_state.updated_content}
						<button
							type="button"
							class="compact radius_0 justify_content_space_between size_sm py_xs3 font_weight_400"
							class:selected
							class:plain={!selected}
							onclick={() => {
								editor_state.set_content_from_history(entry.created);
								content_editor?.focus();
							}}
						>
							<span>{format(new Date(entry.created), 'HH:mm:ss')}</span>
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
</style>
