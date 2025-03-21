<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Paste_From_Clipboard from '@ryanatkn/fuz/Paste_From_Clipboard.svelte';
	import {slide} from 'svelte/transition';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Diskfile_History_Panel from '$lib/Diskfile_History_Panel.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';
	import type {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import {GLYPH_PASTE, GLYPH_DELETE} from '$lib/glyphs.js';

	interface Props {
		diskfile: Diskfile;
		editor_state: Diskfile_Editor_State;
		save_button_text?: string;
		readonly?: boolean;
		auto_save?: boolean;
		on_accept_disk_changes?: () => void;
		on_reject_disk_changes?: () => void;
	}

	const {
		diskfile,
		editor_state,
		save_button_text = 'save changes',
		readonly = false,
		auto_save = false,
		on_accept_disk_changes,
		on_reject_disk_changes,
	}: Props = $props();

	const zzz = zzz_context.get();

	// Access editor state values directly
	const content = $derived(editor_state.updated_content);
	const has_changes = $derived(editor_state.has_changes);
	const discarded_content = $derived(editor_state.discarded_content);
	const file_changed_on_disk = $derived(editor_state.disk_changed);

	/**
	 * Handle pasting content from clipboard
	 */
	const handle_paste = (text: string) => {
		if (readonly) return;
		editor_state.updated_content += text;
	};

	/**
	 * Handle clearing or restoring content
	 */
	const handle_clear = (value: string) => {
		if (readonly) return;
		editor_state.updated_content = value;
	};
</script>

<!-- Content modification actions (copy, paste, clear) -->
<div class="flex gap_xs">
	<Copy_To_Clipboard text={content} attrs={{class: 'plain'}} />

	{#if !readonly}
		<Paste_From_Clipboard onpaste={handle_paste} attrs={{class: 'plain icon_button size_lg'}}>
			{GLYPH_PASTE}
		</Paste_From_Clipboard>

		<Clear_Restore_Button value={content} onchange={handle_clear} />
	{/if}

	<!-- Delete button is always available -->
	<Confirm_Button
		onconfirm={() => zzz.diskfiles.delete(diskfile.path)}
		attrs={{class: 'plain icon_button', title: `delete ${diskfile.pathname}`}}
	>
		{GLYPH_DELETE}
	</Confirm_Button>
</div>

<!-- File changed on disk notification -->
{#if file_changed_on_disk}
	<div class="disk_change_alert panel p_sm mt_sm shadow_inset_top_xs" transition:slide>
		<Diskfile_History_Panel {editor_state} {on_accept_disk_changes} {on_reject_disk_changes} />
	</div>
{/if}

{#if !readonly && !auto_save}
	<div class="mt_xs flex gap_sm" transition:slide>
		<button
			class="flex_1 color_a"
			type="button"
			disabled={!has_changes}
			onclick={() => editor_state.save_changes()}
		>
			{save_button_text}
		</button>

		<Clear_Restore_Button
			value={discarded_content ? '' : has_changes ? content : ''}
			onchange={(value) => editor_state.discard_changes(value)}
			attrs={{
				disabled: !has_changes && discarded_content === null,
				class: 'plain flex_1 white_space_nowrap', // nowrap is a hack, some weirdness with the height of the clear/restore stuff
			}}
		>
			discard changes
			{#snippet restore()}
				undo discard
			{/snippet}
		</Clear_Restore_Button>
	</div>
{/if}

<style>
	.disk_change_alert {
		border-left: 3px solid var(--color_c);
		margin-bottom: var(--space_sm);
	}
</style>
