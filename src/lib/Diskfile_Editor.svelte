<script lang="ts">
	import {slide} from 'svelte/transition';
	import {format} from 'date-fns';
	import {untrack} from 'svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Diskfile_Info from '$lib/Diskfile_Info.svelte';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import Diskfile_Actions from '$lib/Diskfile_Actions.svelte';
	import {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';

	interface Props {
		diskfile: Diskfile;
	}

	const {diskfile}: Props = $props();
	const zzz = zzz_context.get();

	// TODO maybe store per-diskfile editor state
	// Create editor state once and reuse it
	const editor_state = new Diskfile_Editor_State({zzz, diskfile});
	// TODO could this be refactored to be cleaner/more encapsulated? maybe the Diskfile_Editor_State could take a thunk
	// When the diskfile changes, update the editor state with the new diskfile
	$effect.pre(() => {
		// We need to track both the ID to ensure we detect all changes
		diskfile.id;

		untrack(() => {
			// Update the editor state with the new diskfile
			editor_state.update_diskfile(diskfile);
		});
	});

	// Reference to the content editor component
	let content_editor: {focus: () => void} | undefined = $state();

	// Handle content change events
	const handle_content_change = (content: string) => {
		editor_state.updated_content = content;
	};
</script>

<div class="flex h_100">
	<div class="flex_1 h_100 column">
		<Content_Editor
			content={editor_state.updated_content}
			onchange={handle_content_change}
			placeholder={diskfile.pathname}
			show_stats
			readonly={false}
			attrs={{class: 'radius_0'}}
			bind:this={content_editor}
		/>

		{#if editor_state.content_history.length > 1}
			<div class="history mt_xs" transition:slide={{duration: 120}}>
				<details>
					<summary class="size_sm"
						>Edit History ({editor_state.content_history.length} entries)</summary
					>
					<menu class="unstyled flex flex_column_reverse mt_xs">
						{#each editor_state.content_history as entry (entry.created)}
							<!-- TODO the .plain conditional is due to a bug in Moss -->
							<!-- TODO should show two distinct states - selected, and equal to selected (not sure what visual for the latter) -->
							{@const selected = entry.content === editor_state.updated_content}
							<button
								type="button"
								class="justify_content_space_between size_sm py_xs3"
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
				</details>
			</div>
		{/if}
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
	</div>
</div>

<style>
	.history {
		border-top: 1px solid var(--border_color_1);
		padding-top: var(--space_xs);
	}

	summary {
		cursor: pointer;
	}

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
