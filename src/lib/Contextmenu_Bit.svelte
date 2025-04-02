<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';

	import type {Bit_Type} from '$lib/bit.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_BIT, GLYPH_DELETE, GLYPH_EDIT} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Contextmenu_Copy_To_Clipboard from '$lib/Contextmenu_Copy_To_Clipboard.svelte';
	import Bit_View from '$lib/Bit_View.svelte';
	import {get_bit_type_glyph} from '$lib/bit_helpers.js';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		bit: Bit_Type;
	}

	const {bit, ...rest}: Props = $props();

	const zzz = zzz_context.get();

	// Dialog state
	let show_editor = $state(false);
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}{get_bit_type_glyph(bit)}{/snippet}
		bit

		{#snippet menu()}
			<!-- TODO @many maybe a copy submenu on this item with copy id, name, etc, leverage generic cells -->
			{#if bit.content !== null && bit.content !== undefined}
				<Contextmenu_Copy_To_Clipboard
					content={bit.content}
					label="copy content"
					preview={bit.content_preview ?? undefined}
				/>
			{/if}

			<Contextmenu_Entry run={() => (show_editor = true)}>
				{#snippet icon()}{GLYPH_EDIT}{/snippet}
				<span>edit bit</span>
			</Contextmenu_Entry>

			<Contextmenu_Entry
				run={() => {
					// TODO @many better confirmation
					// eslint-disable-next-line no-alert
					if (confirm(`Are you sure you want to delete this bit "${bit.name || 'unnamed'}"?`)) {
						zzz.bits.remove(bit.id);
					}
				}}
			>
				{#snippet icon()}{GLYPH_DELETE}{/snippet}
				<span>delete bit</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}

{#if show_editor}
	<Dialog onclose={() => (show_editor = false)}>
		<div class="pane p_md width_md mx_auto">
			<h2 class="mt_0 mb_sm"><Glyph icon={GLYPH_BIT} /> edit bit</h2>
			<Bit_View {bit} />
		</div>
	</Dialog>
{/if}
