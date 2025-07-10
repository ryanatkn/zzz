<script lang="ts">
	import type {ComponentProps, Snippet} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import {GLYPH_DELETE, GLYPH_FILE, GLYPH_REMOVE} from '$lib/glyphs.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import Contextmenu_Entry_Copy_To_Clipboard from '$lib/Contextmenu_Entry_Copy_To_Clipboard.svelte';
	import Glyph from '$lib/Glyph.svelte';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		diskfile: Diskfile | null | undefined;
		children: Snippet;
	}

	const {diskfile, children, ...rest}: Props = $props();

	const app = frontend_context.get();
</script>

{#if diskfile}
	<Contextmenu {...rest} {entries} {children} />
{:else}
	{@render children()}
{/if}

{#snippet entries()}
	{#if diskfile}
		{@const {diskfiles} = diskfile.app}
		{@const {tabs} = diskfiles.editor}
		{@const tab = tabs.by_diskfile_id.get(diskfile.id)}
		{@const selected = diskfile === tabs.selected_tab?.diskfile}
		<Contextmenu_Submenu>
			{#snippet icon()}<Glyph glyph={GLYPH_FILE} />{/snippet}
			file
			{#snippet menu()}
				<!-- TODO maybe show disabled versions? changing what appears isn't great -->
				{#if !selected || tab?.is_preview}
					<Contextmenu_Entry
						run={() => {
							diskfiles.select(diskfile.id, true);
						}}
					>
						{#snippet icon()}<Glyph glyph={GLYPH_FILE} />{/snippet}
						<span>select tab</span>
					</Contextmenu_Entry>
				{/if}

				{#if !tab || (!selected && tab.is_preview)}
					<Contextmenu_Entry
						run={() => {
							diskfiles.select(diskfile.id, false);
						}}
					>
						{#snippet icon()}<Glyph glyph={GLYPH_FILE} />{/snippet}
						<span>preview tab</span>
					</Contextmenu_Entry>
				{/if}

				{#if tab}
					<Contextmenu_Entry
						run={() => {
							diskfiles.editor.close_tab(tab.id);
						}}
					>
						{#snippet icon()}<Glyph glyph={GLYPH_REMOVE} />{/snippet}
						<span>close tab</span>
					</Contextmenu_Entry>
				{/if}

				{#if diskfile.path_relative}
					<Contextmenu_Entry_Copy_To_Clipboard
						content={diskfile.path_relative}
						label="copy file path"
					/>
				{/if}

				{#if diskfile.content}
					<Contextmenu_Entry_Copy_To_Clipboard
						content={diskfile.content}
						label="copy file content"
						preview={diskfile.content_preview}
					/>
				{/if}
				<Contextmenu_Entry
					run={async () => {
						// TODO @many better confirmation
						// eslint-disable-next-line no-alert
						if (confirm(`Are you sure you want to delete ${diskfile.path_relative}?`)) {
							await app.diskfiles.delete(diskfile.path);
						}
					}}
				>
					{#snippet icon()}<Glyph glyph={GLYPH_DELETE} />{/snippet}
					<span>delete file</span>
				</Contextmenu_Entry>
			{/snippet}
		</Contextmenu_Submenu>
	{/if}
{/snippet}
