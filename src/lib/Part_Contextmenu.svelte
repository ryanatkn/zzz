<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';

	import type {Part_Union} from '$lib/part.svelte.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import {GLYPH_PART, GLYPH_DELETE, GLYPH_EDIT} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Contextmenu_Entry_Copy_To_Clipboard from '$lib/Contextmenu_Entry_Copy_To_Clipboard.svelte';
	import Part_View from '$lib/Part_View.svelte';
	import {get_part_type_glyph} from '$lib/part_helpers.js';
	import Contextmenu_Entry_Toggle from '$lib/Contextmenu_Entry_Toggle.svelte';

	const {
		part,
		...rest
	}: Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> & {
		part: Part_Union;
	} = $props();

	const app = frontend_context.get();

	let show_editor = $state(false);
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}{get_part_type_glyph(part)}{/snippet}
		part

		{#snippet menu()}
			<!-- TODO @many maybe a copy submenu on this item with copy id, name, etc, leverage generic cells -->
			{#if part.content !== null && part.content !== undefined}
				<Contextmenu_Entry_Copy_To_Clipboard
					content={part.content}
					label="copy content"
					preview={part.content_preview ?? undefined}
				/>
			{/if}

			<Contextmenu_Entry_Toggle bind:enabled={part.enabled} label="part" />

			<Contextmenu_Entry run={() => (show_editor = true)}>
				{#snippet icon()}<Glyph glyph={GLYPH_EDIT} />{/snippet}
				<span>edit part</span>
			</Contextmenu_Entry>

			<Contextmenu_Entry
				run={() => {
					// TODO @many better confirmation
					// eslint-disable-next-line no-alert
					if (confirm(`Are you sure you want to delete this part "${part.name || 'unnamed'}"?`)) {
						app.parts.remove(part.id);
					}
				}}
			>
				{#snippet icon()}<Glyph glyph={GLYPH_DELETE} />{/snippet}
				<span>delete part</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}

{#if show_editor}
	<Dialog onclose={() => (show_editor = false)}>
		<div class="pane p_md width_upto_md mx_auto">
			<h2 class="mt_0 mb_sm"><Glyph glyph={GLYPH_PART} /> edit part</h2>
			<Part_View {part} />
		</div>
	</Dialog>
{/if}
