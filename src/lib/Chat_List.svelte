<script lang="ts">
	import {slide} from 'svelte/transition';

	import Chat_Listitem from '$lib/Chat_Listitem.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {sort_by_text, sort_by_numeric} from '$lib/sortable.svelte.js';
	import type {Chat} from '$lib/chat.svelte.js';
	import Sortable_List from '$lib/Sortable_List.svelte';

	const zzz = zzz_context.get();
	const {chats} = zzz;
	const selected_chat_id = $derived(chats.selected_id);
</script>

<Sortable_List
	items={chats.ordered_items}
	show_sort_controls={chats.show_sort_controls}
	sorters={[
		sort_by_numeric<Chat>('updated_newest', 'updated (latest)', 'updated', 'desc'),
		sort_by_numeric<Chat>('updated_oldest', 'updated (past)', 'updated', 'asc'),
		sort_by_numeric<Chat>('created_newest', 'created (newest)', 'created', 'desc'),
		sort_by_numeric<Chat>('created_oldest', 'created (oldest)', 'created', 'asc'),
		sort_by_text<Chat>('name_asc', 'name (a-z)', 'name'),
		sort_by_text<Chat>('name_desc', 'name (z-a)', 'name', 'desc'),
	]}
	sort_key_default="updated_newest"
>
	{#snippet children(chat)}
		<div transition:slide>
			<Chat_Listitem {chat} selected={chat.id === selected_chat_id} />
		</div>
	{/snippet}
</Sortable_List>
