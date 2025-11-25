<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import ContextmenuEntry from '@ryanatkn/fuz/ContextmenuEntry.svelte';
	import ContextmenuSubmenu from '@ryanatkn/fuz/ContextmenuSubmenu.svelte';
	import type {OmitStrict} from '@ryanatkn/belt/types.js';
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';

	import type {Turn} from './turn.svelte.js';
	import {GLYPH_EDIT, GLYPH_TURN} from './glyphs.js';
	import ContextmenuEntryCopyToClipboard from './ContextmenuEntryCopyToClipboard.svelte';
	import TurnView from './TurnView.svelte';
	import Glyph from './Glyph.svelte';

	const {
		turn,
		...rest
	}: OmitStrict<ComponentProps<typeof Contextmenu>, 'entries'> & {
		turn: Turn;
	} = $props();

	let show_editor = $state(false);
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<ContextmenuSubmenu>
		{#snippet icon()}<Glyph glyph={GLYPH_TURN} />{/snippet}
		turn
		{#snippet menu()}
			{#if turn.content}
				<ContextmenuEntryCopyToClipboard
					content={turn.content}
					label="copy content"
					preview={turn.content}
				/>
			{/if}

			<ContextmenuEntry run={() => (show_editor = true)}>
				{#snippet icon()}<Glyph glyph={GLYPH_EDIT} />{/snippet}
				<span>edit content</span>
			</ContextmenuEntry>

			{#if turn.request}
				<ContextmenuEntryCopyToClipboard
					content={() => JSON.stringify(turn.request, null, 2)}
					label="copy request data"
					preview=""
				/>
			{/if}

			{#if turn.response}
				<ContextmenuEntryCopyToClipboard
					content={() => JSON.stringify(turn.response, null, 2)}
					label="copy response data"
					preview=""
				/>
			{/if}
		{/snippet}
	</ContextmenuSubmenu>
{/snippet}

{#if show_editor}
	<Dialog onclose={() => (show_editor = false)}>
		<div class="pane p_md width_upto_md mx_auto">
			<h2 class="mt_0 mb_sm"><Glyph glyph={GLYPH_TURN} /> edit turn</h2>
			<TurnView {turn} />
		</div>
	</Dialog>
{/if}
