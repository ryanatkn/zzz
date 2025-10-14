<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';

	import type {Turn} from '$lib/turn.svelte.js';
	import {GLYPH_EDIT, GLYPH_TURN} from '$lib/glyphs.js';
	import Contextmenu_Entry_Copy_To_Clipboard from '$lib/Contextmenu_Entry_Copy_To_Clipboard.svelte';
	import Turn_View from '$lib/Turn_View.svelte';
	import Glyph from '$lib/Glyph.svelte';

	const {
		turn,
		...rest
	}: Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> & {
		turn: Turn;
	} = $props();

	let show_editor = $state(false);
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}<Glyph glyph={GLYPH_TURN} />{/snippet}
		turn
		{#snippet menu()}
			{#if turn.content}
				<Contextmenu_Entry_Copy_To_Clipboard
					content={turn.content}
					label="copy content"
					preview={turn.content}
				/>
			{/if}

			<Contextmenu_Entry run={() => (show_editor = true)}>
				{#snippet icon()}<Glyph glyph={GLYPH_EDIT} />{/snippet}
				<span>edit content</span>
			</Contextmenu_Entry>

			{#if turn.request}
				<Contextmenu_Entry_Copy_To_Clipboard
					content={() => JSON.stringify(turn.request, null, 2)}
					label="copy request data"
					preview=""
				/>
			{/if}

			{#if turn.response}
				<Contextmenu_Entry_Copy_To_Clipboard
					content={() => JSON.stringify(turn.response, null, 2)}
					label="copy response data"
					preview=""
				/>
			{/if}
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}

{#if show_editor}
	<Dialog onclose={() => (show_editor = false)}>
		<div class="pane p_md width_upto_md mx_auto">
			<h2 class="mt_0 mb_sm"><Glyph glyph={GLYPH_TURN} /> edit turn</h2>
			<Turn_View {turn} />
		</div>
	</Dialog>
{/if}
