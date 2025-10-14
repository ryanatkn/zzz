<script lang="ts">
	import {untrack} from 'svelte';
	import {slide} from 'svelte/transition';

	import {frontend_context} from '$lib/frontend.svelte.js';
	import Diskfile_Info from '$lib/Diskfile_Info.svelte';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import Diskfile_Actions from '$lib/Diskfile_Actions.svelte';
	import {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import Diskfile_History_View from '$lib/Diskfile_History_View.svelte';
	import {GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import Diskfile_Part_View from '$lib/Diskfile_Part_View.svelte';
	import Diskfile_Contextmenu from '$lib/Diskfile_Contextmenu.svelte';
	import type {Uuid} from '$lib/zod_helpers.js';
	import Diskfile_Editor_Nav from '$lib/Diskfile_Editor_Nav.svelte';
	import Tutorial_For_Diskfiles from '$lib/Tutorial_For_Diskfiles.svelte';

	const {
		diskfile,
		onmodified,
	}: {
		diskfile: Diskfile;
		onmodified?: (diskfile_id: Uuid) => void;
	} = $props();

	const app = frontend_context.get();

	// TODO @many refactor, maybe move a collection on `app.diskfiles`? one problem is the contextmenu can't access it without hacking something with context
	const editor_state = new Diskfile_Editor_State({app, diskfile});

	// Reference to the content editor component
	let content_editor: {focus: () => void} | undefined = $state();

	// TODO refactor, try to remove
	$effect(() => {
		if (editor_state.content_was_modified_by_user) {
			onmodified?.(diskfile.id);
		}
	});

	// TODO refactor, try to remove
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
	<div class="display_flex height_100">
		<div class="flex_1 width_atleast_sm height_100 column">
			<Content_Editor
				bind:this={content_editor}
				bind:content={editor_state.current_content}
				token_count={editor_state.current_token_count}
				placeholder={GLYPH_PLACEHOLDER + ' ' + diskfile.path_relative}
				readonly={false}
				attrs={{class: 'height_100 border_radius_0'}}
				onsave={async (value) => {
					await app.diskfiles.update(diskfile.path, value);
				}}
			/>
		</div>

		<div class="width_upto_sm width_atleast_sm py_md">
			<div class="px_md mb_lg">
				<Diskfile_Actions {diskfile} {editor_state} />
			</div>

			<div class="px_md mb_lg">
				<Diskfile_Editor_Nav {editor_state} />
			</div>

			<div class="px_md mb_lg">
				<Diskfile_Info {diskfile} {editor_state} />
			</div>

			{#if editor_state.has_history}
				<div transition:slide>
					<Diskfile_History_View
						{editor_state}
						onselectentry={(entry_id) => {
							editor_state.set_content_from_history(entry_id);
							content_editor?.focus();
						}}
					/>
				</div>
			{/if}

			<Diskfile_Part_View {diskfile} />

			<div class="px_md">
				<Tutorial_For_Diskfiles />
			</div>
		</div>
	</div>
</Diskfile_Contextmenu>
