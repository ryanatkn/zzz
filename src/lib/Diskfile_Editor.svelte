<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import {untrack} from 'svelte';
	import {slide} from 'svelte/transition';
	import {format} from 'date-fns';

	import {to_root_path} from '$lib/path.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Diskfile_Info from '$lib/Diskfile_Info.svelte';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';
	import type {Diskfile} from '$lib/diskfile.svelte.js';

	interface Props {
		file: Diskfile;
	}

	const {file}: Props = $props();

	const {id} = $derived(file);

	const zzz = zzz_context.get();

	let contents_history: Array<{created: number; contents: string}> = $state([]);
	let updated_contents: string = $state(file.contents ?? '');
	let discarded_contents: string | null = $state(null);

	$effect.pre(() => {
		id; // When the file changes, reset the local state
		updated_contents = untrack(() => file.contents) ?? '';
		contents_history = [{created: Date.now(), contents: untrack(() => updated_contents)}];
	});

	const has_changes = $derived(updated_contents !== file.contents);

	const handle_discard_changes = (new_value: string): void => {
		// If we're restoring, the new value is the previously discarded content
		// If we're discarding, the new value is empty and we set updated_contents to the original file contents
		if (new_value) {
			updated_contents = new_value;
			discarded_contents = null;
		} else {
			discarded_contents = updated_contents;
			updated_contents = file.contents ?? '';
		}
	};

	// TODO BLOCK remove the Array.froms below
</script>

<div class="flex h_100">
	<div class="flex_1">
		<div class="h_100">
			<textarea
				class="plain file_editor_textarea h_100 w_100 p_sm font_mono radius_0"
				bind:value={updated_contents}
				placeholder="File contents..."
			></textarea>
		</div>
	</div>

	<div class="width_sm">
		<div class="mb_md p_sm">
			<!-- TODO .panel here looks too heavy I think, though we probably want an abstraction for theming -->
			<div class="p_xs">
				<Diskfile_Info {file} />
			</div>
		</div>

		<div class="row flex_wrap justify_content_space_between gap_xs mb_sm p_sm">
			<Copy_To_Clipboard text={file.contents} attrs={{class: 'plain'}} />

			<Clear_Restore_Button
				value={discarded_contents ? '' : updated_contents === file.contents ? '' : updated_contents}
				onchange={handle_discard_changes}
				attrs={{disabled: !has_changes && discarded_contents === null}}
			>
				discard changes
				{#snippet restore()}
					undo discard
				{/snippet}
			</Clear_Restore_Button>

			<button
				class="color_a"
				type="button"
				disabled={!has_changes}
				onclick={() => {
					contents_history.push({created: Date.now(), contents: updated_contents});
					zzz.diskfiles.update(file.path, updated_contents); // Use path instead of file_id
					discarded_contents = null;
				}}>save changes</button
			>

			<Confirm_Button onclick={() => zzz.diskfiles.delete(file.path)} attrs={{class: 'color_c'}}>
				<!-- Use path instead of file_id -->
				{#snippet children()}
					delete file
				{/snippet}
			</Confirm_Button>
		</div>

		{#if contents_history.length > 1 || contents_history[0].contents !== updated_contents}
			<div class="mt_md panel p_md" transition:slide>
				<h3 class="mt_0 mb_md">Edit History</h3>
				<menu class="unstyled flex flex_column_reverse">
					{#each contents_history as entry (entry)}
						<button
							type="button"
							class="justify_content_space_between"
							class:selected={entry.contents === updated_contents}
							onclick={() => {
								updated_contents = entry.contents;
								discarded_contents = null;
							}}
							transition:slide
						>
							<span>{format(new Date(entry.created), 'HH:mm:ss')}</span>
							<span>{entry.contents.length} chars</span>
						</button>
					{/each}
				</menu>
			</div>
		{/if}

		{#if file.dependencies_count || file.dependents_count}
			<div class="mt_md panel p_md">
				{#if file.dependencies_count}
					<div class="mb_md">
						<h3 class="mt_0 mb_sm">
							Dependencies ({file.dependencies_count})
						</h3>
						<div class="dep_list">
							{#each file.dependency_ids as dependency_id (dependency_id)}
								<div class="dep_item">{to_root_path(dependency_id)}</div>
							{/each}
						</div>
					</div>
				{/if}

				{#if file.dependents_count}
					<div>
						<h3 class="mt_0 mb_sm">
							Dependents ({file.dependents_count})
						</h3>
						<div class="dep_list">
							{#each file.dependent_ids as dependent_id (dependent_id)}
								<div class="dep_item">{to_root_path(dependent_id)}</div>
							{/each}
						</div>
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>

<style>
	.file_editor_textarea {
		resize: none;
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
		background: var(--color_bg_alt);
		border-radius: var(--radius_xs);
	}
</style>
