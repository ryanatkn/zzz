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
	import Contextmenu_Copy_To_Clipboard from '$lib/Contextmenu_Copy_To_Clipboard.svelte';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		prompt: Prompt;
	}

	const {prompt, ...rest}: Props = $props();

	const zzz = zzz_context.get();
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}{GLYPH_PROMPT}{/snippet}
		prompt
		{#snippet menu()}
			<!-- TODO @many maybe a copy submenu on this item with copy id, name, etc, leverage generic cells -->
			<Contextmenu_Copy_To_Clipboard
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
							name: 'Text bit',
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
					const diskfiles = zzz.diskfiles.items.all;
					if (!diskfiles.length) {
						alert('No files available. Add files first.'); // eslint-disable-line no-alert
						return;
					}

					// TODO BLOCK show diskfile pick
					const diskfile = diskfiles[0];
					const diskfile_name = diskfile.path.split('/').pop() || 'unnamed';

					prompt.add_bit(
						Bit.create(zzz, {
							type: 'diskfile',
							path: diskfile.path,
							name: diskfile_name,
						}),
					);
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
							name: 'sequence bit',
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
