<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import {GLYPH_DELETE, GLYPH_FILE} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Contextmenu_Entry_Copy_To_Clipboard from '$lib/Contextmenu_Entry_Copy_To_Clipboard.svelte';
	import Glyph from '$lib/Glyph.svelte';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		diskfile: Diskfile;
	}

	const {diskfile, ...rest}: Props = $props();

	const zzz = zzz_context.get();
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}<Glyph glyph={GLYPH_FILE} />{/snippet}
		file
		{#snippet menu()}
			<!-- TODO maybe show disabled versions? changing what appears isn't great -->
			{#if diskfile.content}
				<Contextmenu_Entry_Copy_To_Clipboard
					content={diskfile.content}
					label="copy file content"
					preview={diskfile.content_preview}
				/>
			{/if}

			{#if diskfile.path_relative}
				<Contextmenu_Entry_Copy_To_Clipboard
					content={diskfile.path_relative}
					label="copy file path"
				/>
			{/if}

			<Contextmenu_Entry
				run={() => {
					// TODO @many better confirmation
					// eslint-disable-next-line no-alert
					if (confirm(`Are you sure you want to delete ${diskfile.path_relative}?`)) {
						zzz.diskfiles.delete(diskfile.path);
					}
				}}
			>
				{#snippet icon()}<Glyph glyph={GLYPH_DELETE} />{/snippet}
				<span>delete file</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}
