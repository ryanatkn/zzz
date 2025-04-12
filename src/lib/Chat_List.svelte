<script lang="ts">
	import {slide} from 'svelte/transition';

	import Chat_Listitem from '$lib/Chat_Listitem.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {Reorderable} from '$lib/reorderable.svelte.js';

	const zzz = zzz_context.get();
	const {chats} = zzz;
	const selected_chat_id = $derived(chats.selected_id);

	const reorderable = new Reorderable();
</script>

<menu
	class="unstyled mt_sm"
	use:reorderable.list={{
		onreorder: (from_index, to_index) => chats.reorder_chats(from_index, to_index),
	}}
>
	{#each chats.ordered_items as chat, index (chat.id)}
		<li use:reorderable.item={{index}} transition:slide>
			<Chat_Listitem {chat} selected={chat.id === selected_chat_id} />
		</li>
	{/each}
</menu>
