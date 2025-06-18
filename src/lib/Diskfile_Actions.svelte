<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Paste_From_Clipboard from '@ryanatkn/fuz/Paste_From_Clipboard.svelte';
	import {slide} from 'svelte/transition';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {zzz_context} from '$lib/frontend.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';
	import type {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import {GLYPH_PASTE, GLYPH_DELETE} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	interface Props {
		diskfile: Diskfile;
		editor_state: Diskfile_Editor_State;
		save_button_text?: string | undefined;
		readonly?: boolean | undefined;
		auto_save?: boolean | undefined;
	}

	const {
		diskfile,
		editor_state,
		save_button_text = 'save changes',
		readonly = false,
		auto_save = false,
	}: Props = $props();

	const app = zzz_context.get();

	const content = $derived(editor_state.current_content);
	const has_changes = $derived(editor_state.has_changes);
</script>

<!-- Content modification actions (copy, paste, clear) -->
<div class="display_flex gap_xs">
	<Copy_To_Clipboard text={content} attrs={{class: 'plain'}} />

	{#if !readonly}
		<Paste_From_Clipboard
			onpaste={(text) => {
				editor_state.current_content += text;
			}}
			attrs={{class: 'plain icon_button font_size_lg'}}
		>
			<Glyph glyph={GLYPH_PASTE} />
		</Paste_From_Clipboard>

		<Clear_Restore_Button
			value={content}
			onchange={(value) => {
				editor_state.current_content = value;
			}}
		/>
	{/if}

	<!-- Delete button is always available -->
	<Confirm_Button
		onconfirm={() => app.diskfiles.delete(diskfile.path)}
		attrs={{class: 'plain icon_button', title: 'delete file'}}
	>
		<Glyph glyph={GLYPH_DELETE} />
	</Confirm_Button>
</div>

{#if !readonly && !auto_save}
	<div class="mt_xs display_flex" transition:slide>
		<button
			class="flex_1 color_a"
			type="button"
			disabled={!has_changes}
			onclick={() => editor_state.save_changes()}
		>
			{save_button_text}
		</button>
	</div>
{/if}
