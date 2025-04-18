<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import {Bit} from '$lib/bit.svelte.js';
	import type {Prompt} from '$lib/prompt.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {
		GLYPH_BIT,
		GLYPH_DELETE,
		GLYPH_FILE,
		GLYPH_LIST,
		GLYPH_PROMPT,
		GLYPH_REMOVE,
	} from '$lib/glyphs.js';
	import Contextmenu_Entry_Copy_To_Clipboard from '$lib/Contextmenu_Entry_Copy_To_Clipboard.svelte';
	import Diskfile_Picker from '$lib/Diskfile_Picker.svelte';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		prompt: Prompt;
	}

	const {prompt, ...rest}: Props = $props();

	const zzz = zzz_context.get();

	let show_diskfile_picker = $state(false);
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}{GLYPH_PROMPT}{/snippet}
		prompt
		{#snippet menu()}
			<!-- TODO @many maybe a copy submenu on this item with copy id, name, etc, leverage generic cells -->
			<Contextmenu_Entry_Copy_To_Clipboard
				content={prompt.content}
				label="copy content"
				preview={prompt.content_preview}
			/>

			<Contextmenu_Entry
				run={() => {
					prompt.add_bit(
						Bit.create(zzz, {
							type: 'text',
							content: '',
						}),
					);
				}}
			>
				{#snippet icon()}{GLYPH_BIT}{/snippet}
				<span>add text bit</span>
			</Contextmenu_Entry>
			<Contextmenu_Entry
				run={() => {
					// Get all available files
					if (!zzz.diskfiles.items.size) {
						alert('No files available. Add files first.'); // eslint-disable-line no-alert
						return;
					}

					show_diskfile_picker = true;
				}}
			>
				{#snippet icon()}{GLYPH_FILE}{/snippet}
				<span>add file bit</span>
			</Contextmenu_Entry>
			<Contextmenu_Entry
				run={() => {
					prompt.add_bit(
						Bit.create(zzz, {
							type: 'sequence',
						}),
					);
				}}
			>
				{#snippet icon()}{GLYPH_LIST}{/snippet}
				<span>add sequence bit</span>
			</Contextmenu_Entry>
			{#if prompt.bits.length}
				<Contextmenu_Entry run={() => prompt.remove_all_bits()}>
					{#snippet icon()}{GLYPH_REMOVE}{/snippet}
					<span>remove all bits</span>
				</Contextmenu_Entry>
			{/if}
			<!-- <Contextmenu_Entry
				run={() => {
					// TODO implement
					// prompt.rename() after bit name picker
				}}
			>
				{#snippet icon()}{GLYPH_EDIT}{/snippet}
				<span>Rename prompt</span>
			</Contextmenu_Entry> -->
			<Contextmenu_Entry
				run={() => {
					// TODO confirm dialog that shows the prompt's summary
					// TODO @many better confirmation
					// eslint-disable-next-line no-alert
					if (confirm(`Are you sure you want to delete prompt "${prompt.name}"?`)) {
						zzz.prompts.remove(prompt);
					}
				}}
			>
				{#snippet icon()}{GLYPH_DELETE}{/snippet}
				<span>delete prompt</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}

<Diskfile_Picker
	bind:show={show_diskfile_picker}
	onpick={(diskfile) => {
		if (!diskfile) return false;

		prompt.add_bit(
			Bit.create(zzz, {
				type: 'diskfile',
				path: diskfile.path,
			}),
		);
		return true;
	}}
/>
