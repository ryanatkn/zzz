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
	import Diskfile_Picker_Dialog from '$lib/Diskfile_Picker_Dialog.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_FILE, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';

	interface Props {
		diskfile_bit: Diskfile_Bit;
		show_actions?: boolean | undefined;
	}

	const {diskfile_bit, show_actions = true}: Props = $props();

	const zzz = zzz_context.get();

	const {diskfile} = $derived(diskfile_bit);

	// Create editor state reference - will be initialized in the effect
	// TODO @many this initialization is awkward, ideally becomes refactored to mostly derived
	// maybe this instance is created once, and it gets a thunk for the diskfile? `Dikfile_Editor_State.of(() => diskfile)`
	let editor_state: Diskfile_Editor_State | undefined = $state();

	// Keep track of the content editor for focusing
	let content_editor: {focus: () => void} | undefined = $state();

	let show_file_picker = $state(false);

	// TODO probably refactor to avoid the effect, look also at `TODO @many refactor, maybe move a collection on `zzz.diskfiles`?`
	// Effect for managing editor state lifecycle
	$effect.pre(() => {
		// Track the diskfile from the bit
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
				editor_state = new Diskfile_Editor_State({zzz, diskfile}); // TODO @many refactor, maybe move a collection on `zzz.diskfiles`?
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

<div class="mb_xs">
	{#if diskfile}
		<small class="mb_xs block formatted">
			{diskfile.path_relative}
		</small>
	{/if}
	<button
		type="button"
		class="plain compact"
		onclick={() => {
			show_file_picker = true;
		}}
	>
		<Glyph glyph={GLYPH_FILE} />
		<small class="ml_xs2">pick file</small>
	</button>
</div>

{#if diskfile && editor_state}
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
				placeholder={GLYPH_PLACEHOLDER + ' ' + diskfile.path_relative}
				show_stats={false}
				readonly={false}
				onsave={(value) => {
					zzz.diskfiles.update(diskfile.path, value);
				}}
			/>

			{#if show_actions}
				<div class="mt_xs">
					<Diskfile_Actions {diskfile} {editor_state} />
				</div>
			{/if}
		</div>

		{#if editor_state}
			<div class="my_xs font_size_sm">
				<Diskfile_Metrics {editor_state} />
			</div>
		{/if}

		{#if editor_state.has_history}
			<div transition:slide>
				<Diskfile_History_View
					{editor_state}
					onselectentry={(entry_id) => {
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
		placeholder="[no file]"
		attrs={{disabled: true}}
	/>
{/if}

<Diskfile_Picker_Dialog
	selected_ids={diskfile ? [diskfile.id] : []}
	bind:show={show_file_picker}
	onpick={(diskfile) => {
		if (diskfile !== undefined) {
			diskfile_bit.path = diskfile ? diskfile.path : diskfile;
		}
	}}
/>
