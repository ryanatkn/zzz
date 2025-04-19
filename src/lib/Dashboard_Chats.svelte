<script lang="ts">
	import {random_item} from '@ryanatkn/belt/random.js';
	import {fade} from 'svelte/transition';

	import Chats_List from '$lib/Chat_List.svelte';
	import Chat_View from '$lib/Chat_View.svelte';
	import Contextmenu_Chat from '$lib/Contextmenu_Chat.svelte';
	import {GLYPH_ADD, GLYPH_SORT} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Glyph from '$lib/Glyph.svelte';

	const zzz = zzz_context.get();
	const {chats} = zzz;

	const create_and_select_chat = async () => {
		const chat = chats.add();
		return chats.navigate_to(chat.id);
	};
</script>

<div class="flex w_100 h_100">
	<!-- TODO show the selected chat's info, if any -->
	<div class="column_fixed">
		<div class="py_sm pr_sm">
			<div class="row gap_xs2 mb_xs pl_xs2">
				<button
					class="plain flex_1 justify_content_start"
					type="button"
					onclick={create_and_select_chat}
				>
					<Glyph text={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> new chat
				</button>
				{#if chats.items.size > 1}
					<button
						type="button"
						class="plain compact selectable deselectable"
						class:selected={chats.show_sort_controls}
						title="toggle sort controls"
						onclick={() => chats.toggle_sort_controls()}
					>
						<Glyph text={GLYPH_SORT} />
					</button>
				{/if}
			</div>
			{#if chats.items.size}
				<Chats_List />
			{/if}
		</div>
	</div>
	{#if chats.selected}
		<Contextmenu_Chat chat={chats.selected}>
			<Chat_View chat={chats.selected} />
		</Contextmenu_Chat>
	{:else if chats.items.size}
		<div class="flex align_items_center justify_content_center h_100 flex_1" in:fade>
			<p>
				select a chat from the list or <button
					type="button"
					class="inline color_d"
					onclick={create_and_select_chat}>create one</button
				>
				or
				<button
					type="button"
					class="inline color_f"
					onclick={() => {
						const chat = random_item(chats.ordered_items);
						void chats.navigate_to(chat.id);
					}}>go fish</button
				>?
			</p>
		</div>
	{:else}
		<div class="flex align_items_center justify_content_center h_100 flex_1" in:fade>
			<p>
				no chats available, <button
					type="button"
					class="inline color_d"
					onclick={create_and_select_chat}>create one</button
				>?
			</p>
		</div>
	{/if}
</div>
