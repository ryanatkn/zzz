<script lang="ts">
	import {base} from '$app/paths';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import Chat_Contextmenu from '$lib/Chat_Contextmenu.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_CHAT} from '$lib/glyphs.js';
	import type {Chat} from '$lib/chat.svelte.js';

	interface Props {
		chat: Chat;
		selected?: boolean | undefined;
	}

	const {chat, selected}: Props = $props();
</script>

<Chat_Contextmenu {chat}>
	<Nav_Link
		href="{base}/chats/{chat.id}"
		{selected}
		attrs={{
			class: 'justify_content_space_between',
			style: 'min-height: 0;',
		}}
	>
		<div class="ellipsis">
			<Glyph attrs={{class: 'mr_xs2'}} glyph={GLYPH_CHAT} />
			<span>{chat.name}</span>
		</div>
		{#if chat.tapes.length}<small>{chat.tapes.length}</small>{/if}
	</Nav_Link>
</Chat_Contextmenu>
