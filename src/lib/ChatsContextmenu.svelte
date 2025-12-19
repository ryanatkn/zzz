<script lang="ts">
	import type {ComponentProps, Snippet} from 'svelte';
	import Contextmenu from '@fuzdev/fuz_ui/Contextmenu.svelte';
	import type {OmitStrict} from '@fuzdev/fuz_util/types.js';
	import ContextmenuEntry from '@fuzdev/fuz_ui/ContextmenuEntry.svelte';

	import {frontend_context} from './frontend.svelte.js';
	import {GLYPH_CHAT} from './glyphs.js';
	import Glyph from './Glyph.svelte';

	const props: OmitStrict<ComponentProps<typeof Contextmenu>, 'entries'> & {children: Snippet} =
		$props();

	const app = frontend_context.get();
</script>

<Contextmenu {...props} {entries} />

{#snippet entries()}
	<ContextmenuEntry
		run={() => {
			app.chats.add(undefined, true);
		}}
	>
		{#snippet icon()}<Glyph glyph={GLYPH_CHAT} />{/snippet}
		<span>create new chat</span>
	</ContextmenuEntry>
{/snippet}
