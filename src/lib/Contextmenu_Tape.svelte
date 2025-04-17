<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Tape} from '$lib/tape.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_DELETE, GLYPH_REMOVE, GLYPH_TAPE} from '$lib/glyphs.js';
	import Contextmenu_Entry_Toggle from '$lib/Contextmenu_Entry_Toggle.svelte';
	import Contextmenu_Entry_Copy_To_Clipboard from '$lib/Contextmenu_Entry_Copy_To_Clipboard.svelte';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		tape: Tape;
	}

	const {tape, ...rest}: Props = $props();

	const zzz = zzz_context.get();
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}{GLYPH_TAPE}{/snippet}
		tape
		{#snippet menu()}
			{#if tape.content}
				<Contextmenu_Entry_Copy_To_Clipboard
					content={tape.content}
					label="copy conversation"
					preview={tape.content_preview}
				/>
			{/if}

			{#if tape.strips.size > 0}
				<Contextmenu_Entry
					run={() => {
						tape.remove_all_strips();
					}}
				>
					{#snippet icon()}{GLYPH_REMOVE}{/snippet}
					<span>clear conversation</span>
				</Contextmenu_Entry>
			{/if}

			<Contextmenu_Entry_Toggle bind:enabled={tape.enabled} />

			<Contextmenu_Entry
				run={() => {
					// TODO @many better confirmation
					// eslint-disable-next-line no-alert
					if (confirm(`Are you sure you want to delete this tape?`)) {
						zzz.tapes.remove(tape.id);
					}
				}}
			>
				{#snippet icon()}{GLYPH_DELETE}{/snippet}
				<span>delete tape</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}
