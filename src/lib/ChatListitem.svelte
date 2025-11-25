<script lang="ts">
	import {resolve} from '$app/paths';

	import NavLink from '$lib/NavLink.svelte';
	import ChatContextmenu from '$lib/ChatContextmenu.svelte';
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

<ChatContextmenu {chat}>
	<NavLink
		href={resolve(`/chats/${chat.id}`)}
		{selected}
		class="justify_content_space_between"
		style="min-height: 0;"
	>
		<div class="ellipsis">
			<Glyph glyph={GLYPH_CHAT} />&nbsp;
			<span>{chat.name}</span>
		</div>
		{#if chat.threads.length}<small>{chat.threads.length}</small>{/if}
	</NavLink>
</ChatContextmenu>
