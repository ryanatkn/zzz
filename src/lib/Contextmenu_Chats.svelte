<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import type {Partial_Only} from '@ryanatkn/belt/types.js';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';

	import {zzz_context} from '$lib/frontend.svelte.js';
	import {GLYPH_CHAT} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	type Props = Partial_Only<ComponentProps<typeof Contextmenu>, 'entries'>;

	const props: Props = $props();

	const app = zzz_context.get();
</script>

<Contextmenu {...props} entries={props.entries ?? entries} />

{#snippet entries()}
	<Contextmenu_Entry run={() => app.chats.add(undefined, true)}>
		{#snippet icon()}<Glyph glyph={GLYPH_CHAT} />{/snippet}
		<span>create new chat</span>
	</Contextmenu_Entry>
{/snippet}
