<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';

	import type {Strip} from '$lib/strip.svelte.js';
	import {GLYPH_EDIT, GLYPH_STRIP} from '$lib/glyphs.js';
	import Contextmenu_Copy_To_Clipboard from '$lib/Contextmenu_Copy_To_Clipboard.svelte';
	import Strip_View from '$lib/Strip_View.svelte';
	import Glyph from '$lib/Glyph.svelte';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		strip: Strip;
	}

	const {strip, ...rest}: Props = $props();

	let show_editor = $state(false);
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}{GLYPH_STRIP}{/snippet}
		strip
		{#snippet menu()}
			{#if strip.content}
				<Contextmenu_Copy_To_Clipboard
					content={strip.content}
					label="copy content"
					preview={strip.content}
				/>
			{/if}

			<Contextmenu_Entry run={() => (show_editor = true)}>
				{#snippet icon()}{GLYPH_EDIT}{/snippet}
				<span>edit content</span>
			</Contextmenu_Entry>

			{#if strip.request}
				<Contextmenu_Copy_To_Clipboard
					content={() => JSON.stringify(strip.request, null, 2)}
					label="copy request data"
					preview=""
				/>
			{/if}

			{#if strip.response}
				<Contextmenu_Copy_To_Clipboard
					content={() => JSON.stringify(strip.response, null, 2)}
					label="copy response data"
					preview=""
				/>
			{/if}
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}

{#if show_editor}
	<Dialog onclose={() => (show_editor = false)}>
		<div class="pane p_md width_md mx_auto">
			<h2 class="mt_0 mb_sm"><Glyph icon={GLYPH_STRIP} /> edit strip</h2>
			<Strip_View {strip} />
		</div>
	</Dialog>
{/if}
