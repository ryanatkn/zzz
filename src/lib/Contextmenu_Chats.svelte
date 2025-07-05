<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';

	import {frontend_context} from '$lib/frontend.svelte.js';
	import {GLYPH_CHAT} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	type Props = Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'>;

	const props: Props = $props();

	const app = frontend_context.get();
</script>

<Contextmenu {...props} {entries} />

{#snippet entries()}
	<Contextmenu_Entry run={() => app.chats.add(undefined, true)}>
		{#snippet icon()}<Glyph glyph={GLYPH_CHAT} />{/snippet}
		<span>create new chat</span>
	</Contextmenu_Entry>
{/snippet}
