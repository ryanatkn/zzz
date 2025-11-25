<script lang="ts">
	import CopyToClipboard from '@ryanatkn/fuz/CopyToClipboard.svelte';
	import PasteFromClipboard from '@ryanatkn/fuz/PasteFromClipboard.svelte';
	import {slide} from 'svelte/transition';

	import ConfirmButton from '$lib/ConfirmButton.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import ClearRestoreButton from '$lib/ClearRestoreButton.svelte';
	import type {DiskfileEditorState} from '$lib/diskfile_editor_state.svelte.js';
	import {GLYPH_PASTE, GLYPH_DELETE} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	const {
		diskfile,
		editor_state,
		readonly = false,
		auto_save = false,
	}: {
		diskfile: Diskfile;
		editor_state: DiskfileEditorState;
		readonly?: boolean | undefined;
		auto_save?: boolean | undefined;
	} = $props();

	const app = frontend_context.get();
</script>

<!-- Content modification actions (copy, paste, clear) -->
<div class="display_flex gap_xs">
	<CopyToClipboard text={editor_state.current_content} attrs={{class: 'plain'}} />

	{#if !readonly}
		<PasteFromClipboard
			onpaste={(text) => {
				editor_state.current_content += text;
			}}
			attrs={{class: 'plain icon_button font_size_lg'}}
		>
			<Glyph glyph={GLYPH_PASTE} />
		</PasteFromClipboard>

		<ClearRestoreButton bind:value={editor_state.current_content} />
	{/if}

	<!-- Delete button is always available -->
	<ConfirmButton
		onconfirm={() => app.diskfiles.delete(diskfile.path)}
		class="plain icon_button"
		title="delete file"
	>
		<Glyph glyph={GLYPH_DELETE} />
	</ConfirmButton>
</div>

{#if !readonly && !auto_save}
	<div class="mt_xs display_flex" transition:slide>
		<button
			class="flex_1 color_f"
			type="button"
			disabled={!editor_state.has_changes}
			onclick={() => editor_state.save_changes()}
		>
			save changes
		</button>
	</div>
{/if}
