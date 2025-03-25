<script lang="ts">
	import {slide} from 'svelte/transition';
	import {untrack} from 'svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Diskfile_Info from '$lib/Diskfile_Info.svelte';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import Diskfile_Actions from '$lib/Diskfile_Actions.svelte';
	import {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import Diskfile_History_View from '$lib/Diskfile_History_View.svelte';
	import {GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import Diskfile_Bits_View from '$lib/Diskfile_Bits_View.svelte';
	import Diskfile_Contextmenu from '$lib/Diskfile_Contextmenu.svelte';

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
			// If the diskfile id changed, this is a navigation to a different file
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

<Diskfile_Contextmenu {diskfile}>
	<div class="flex h_100">
		<div class="flex_1 h_100 column">
			<Content_Editor
				bind:this={content_editor}
				bind:content={editor_state.current_content}
				token_count={editor_state.current_token_count}
				placeholder={GLYPH_PLACEHOLDER + ' ' + diskfile.path_relative}
				show_stats
				readonly={false}
				attrs={{class: 'h_100 radius_0'}}
				onsave={(value) => {
					zzz.diskfiles.update(diskfile.path, value);
				}}
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
					<Diskfile_History_View
						{editor_state}
						on_entry_select={(entry_id) => {
							editor_state.set_content_from_history(entry_id);
							content_editor?.focus();
						}}
					/>
				</div>
			{/if}

			<Diskfile_Bits_View {diskfile} />
		</div>
	</div>
</Diskfile_Contextmenu>

<style>
	/* TODO roughed in */
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
