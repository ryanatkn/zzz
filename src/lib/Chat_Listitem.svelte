<script lang="ts">
	import {base} from '$app/paths';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import Chat_Contextmenu from '$lib/Chat_Contextmenu.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_CHAT} from '$lib/glyphs.js';
	import type {Chat} from '$lib/chat.svelte.js';

	const {
		chat,
		selected,
	}: {
		chat: Chat;
		selected?: boolean | undefined;
	} = $props();
</script>

<Chat_Contextmenu {chat}>
	<Nav_Link
		href="{base}/chats/{chat.id}"
		{selected}
		class="justify_content_space_between"
		style="min-height: 0;"
	>
		<div class="ellipsis">
			<Glyph glyph={GLYPH_CHAT} />&nbsp;
			<span>{chat.name}</span>
		</div>
		{#if chat.tapes.length}<small>{chat.tapes.length}</small>{/if}
	</Nav_Link>
</Chat_Contextmenu>
