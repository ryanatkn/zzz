<script lang="ts">
	import {untrack} from 'svelte';
	import {slide} from 'svelte/transition';

	import {Diskfile_Bit} from '$lib/bit.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import Diskfile_Actions from '$lib/Diskfile_Actions.svelte';
	import Diskfile_Metrics from '$lib/Diskfile_Metrics.svelte';
	import {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import Diskfile_History_View from '$lib/Diskfile_History_View.svelte';

	interface Props {
		diskfile_bit: Diskfile_Bit;
		show_actions?: boolean;
	}

	const {diskfile_bit, show_actions = true}: Props = $props();
	const zzz = zzz_context.get();

	// Create editor state reference - will be initialized in the effect
	// TODO @many this initialization is awkward, ideally becomes refactored to mostly derived
	// maybe this instance is created once, and it gets a thunk for the diskfile? `Dikfile_Editor_State.of(() => diskfile)`
	let editor_state: Diskfile_Editor_State | undefined = $state();

	// Keep track of the content editor for focusing
	let content_editor: {focus: () => void} | undefined = $state();

	// Effect for managing editor state lifecycle
	$effect.pre(() => {
		// Track the diskfile from the bit
		const diskfile = diskfile_bit.diskfile;

		if (!diskfile) {
			// Clear editor state if no diskfile is available
			editor_state = undefined;
			diskfile_bit.link_editor_state(null); // TODO @many this initialization is awkward, ideally becomes refactored to mostly derived
			return;
		}

		// Here's the important part: we use untrack to avoid re-creating
		// the editor state on every render while still updating it when needed
		untrack(() => {
			// Create new editor state if it doesn't exist
			if (!editor_state) {
				editor_state = new Diskfile_Editor_State({zzz, diskfile});
				diskfile_bit.link_editor_state(editor_state); // TODO @many this initialization is awkward, ideally becomes refactored to mostly derived
				return;
			}

			// If diskfile id changed, update the editor state with the new diskfile
			if (editor_state.diskfile.id !== diskfile.id) {
				editor_state.update_diskfile(diskfile);
				diskfile_bit.link_editor_state(editor_state); // TODO @many this initialization is awkward, ideally becomes refactored to mostly derived
				return;
			}

			// Check for external disk changes
			if (diskfile.content !== editor_state.last_seen_disk_content) {
				editor_state.check_disk_changes();
			}
		});
	});
</script>

<div class="column">
	<div class="p_xs bg_1 radius_xs mb_xs">
		<div class="font_mono size_sm mb_xs">
			{diskfile_bit.diskfile?.pathname || 'no file selected'}
		</div>
		{#if diskfile_bit.diskfile}
			<div class="mb_xs">
				<button
					type="button"
					class="plain size_sm"
					onclick={() => {
						zzz.diskfiles.select(diskfile_bit.diskfile?.id);
					}}
				>
					View file
				</button>
			</div>
		{:else}
			<em class="fg_1">File not found or not selected</em>
		{/if}
	</div>

	{#if diskfile_bit.diskfile && editor_state}
		<div>
			<div class="column">
				<Content_Editor
					bind:this={content_editor}
					bind:content={
						() => editor_state!.current_content,
						(content) => {
							if (editor_state) {
								editor_state.current_content = content;
							}
						}
					}
					token_count={editor_state.current_token_count}
					placeholder={diskfile_bit.diskfile.pathname}
					show_stats={false}
					readonly={false}
				/>

				{#if show_actions}
					<div class="mt_xs">
						<Diskfile_Actions diskfile={diskfile_bit.diskfile} {editor_state} />
					</div>
				{/if}
			</div>

			<!-- Add file metadata when available -->
			{#if editor_state}
				<div class="my_xs size_sm">
					<Diskfile_Metrics {editor_state} />
				</div>
			{/if}

			{#if editor_state.has_history}
				<div transition:slide class="max_height_sm">
					<Diskfile_History_View
						{editor_state}
						on_entry_select={(entry_id) => {
							if (editor_state) {
								editor_state.set_content_from_history(entry_id);
								content_editor?.focus();
							}
						}}
					/>
				</div>
			{/if}
		</div>
	{:else}
		<Content_Editor
			content={diskfile_bit.content || ''}
			readonly
			placeholder="file not available"
		/>
	{/if}
</div>
