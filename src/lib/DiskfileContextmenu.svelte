<script lang="ts">
	import type {ComponentProps, Snippet} from 'svelte';
	import Contextmenu from '@fuzdev/fuz_ui/Contextmenu.svelte';
	import ContextmenuEntry from '@fuzdev/fuz_ui/ContextmenuEntry.svelte';
	import ContextmenuSubmenu from '@fuzdev/fuz_ui/ContextmenuSubmenu.svelte';
	import type {OmitStrict} from '@fuzdev/fuz_util/types.js';

	import type {Diskfile} from './diskfile.svelte.js';
	import {GLYPH_DELETE, GLYPH_FILE, GLYPH_REMOVE} from './glyphs.js';
	import {frontend_context} from './frontend.svelte.js';
	import ContextmenuEntryCopyToClipboard from './ContextmenuEntryCopyToClipboard.svelte';
	import Glyph from './Glyph.svelte';

	const {
		diskfile,
		children,
		...rest
	}: OmitStrict<ComponentProps<typeof Contextmenu>, 'entries'> & {
		diskfile: Diskfile | null | undefined;
		children: Snippet;
	} = $props();

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
		<ContextmenuSubmenu>
			{#snippet icon()}<Glyph glyph={GLYPH_FILE} />{/snippet}
			file
			{#snippet menu()}
				<!-- TODO maybe show disabled versions? changing what appears isn't great -->
				{#if !selected || tab?.is_preview}
					<ContextmenuEntry
						run={() => {
							diskfiles.select(diskfile.id, true);
						}}
					>
						{#snippet icon()}<Glyph glyph={GLYPH_FILE} />{/snippet}
						<span>select tab</span>
					</ContextmenuEntry>
				{/if}

				{#if !tab || (!selected && tab.is_preview)}
					<ContextmenuEntry
						run={() => {
							diskfiles.select(diskfile.id, false);
						}}
					>
						{#snippet icon()}<Glyph glyph={GLYPH_FILE} />{/snippet}
						<span>preview tab</span>
					</ContextmenuEntry>
				{/if}

				{#if tab}
					<ContextmenuEntry
						run={() => {
							diskfiles.editor.close_tab(tab.id);
						}}
					>
						{#snippet icon()}<Glyph glyph={GLYPH_REMOVE} />{/snippet}
						<span>close tab</span>
					</ContextmenuEntry>
				{/if}

				{#if diskfile.path_relative}
					<ContextmenuEntryCopyToClipboard
						content={diskfile.path_relative}
						label="copy file path"
					/>
				{/if}

				{#if diskfile.content}
					<ContextmenuEntryCopyToClipboard
						content={diskfile.content}
						label="copy file content"
						preview={diskfile.content_preview}
					/>
				{/if}
				<ContextmenuEntry
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
				</ContextmenuEntry>
			{/snippet}
		</ContextmenuSubmenu>
	{/if}
{/snippet}
