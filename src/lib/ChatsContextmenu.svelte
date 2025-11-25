<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import type {OmitStrict} from '@ryanatkn/belt/types.js';
	import ContextmenuEntry from '@ryanatkn/fuz/ContextmenuEntry.svelte';

	import {frontend_context} from '$lib/frontend.svelte.js';
	import {GLYPH_CHAT} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	const props: OmitStrict<ComponentProps<typeof Contextmenu>, 'entries'> = $props();

	const app = frontend_context.get();
</script>

<Contextmenu {...props} {entries} />

{#snippet entries()}
	<ContextmenuEntry run={() => app.chats.add(undefined, true)}>
		{#snippet icon()}<Glyph glyph={GLYPH_CHAT} />{/snippet}
		<span>create new chat</span>
	</ContextmenuEntry>
{/snippet}
