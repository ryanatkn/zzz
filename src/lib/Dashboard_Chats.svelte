<script lang="ts">
	import {random_item} from '@ryanatkn/belt/random.js';

	import Chats_List from '$lib/Chat_List.svelte';
	import Chat_View from '$lib/Chat_View.svelte';
	import Contextmenu_Chat from '$lib/Contextmenu_Chat.svelte';
	import {GLYPH_ADD, GLYPH_SORT} from '$lib/glyphs.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import Glyph from '$lib/Glyph.svelte';
	import Contextmenu_Chats from '$lib/Contextmenu_Chats.svelte';

	const app = frontend_context.get();
	const {chats} = app;
</script>

<Contextmenu_Chats>
	<div class="display_flex w_100 h_100">
		<div class="column_fixed">
			<div class="py_sm pr_sm">
				<div class="row gap_xs2 mb_xs pl_xs2">
					<button
						class="plain flex_1 justify_content_start"
						type="button"
						onclick={() => chats.add(undefined, true)}
					>
						<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> new chat
					</button>
					{#if chats.items.size > 1}
						<button
							type="button"
							class="plain compact selectable deselectable"
							class:selected={chats.show_sort_controls}
							title="toggle sort controls"
							onclick={() => chats.toggle_sort_controls()}
						>
							<Glyph glyph={GLYPH_SORT} />
						</button>
					{/if}
				</div>
				{#if chats.items.size}
					<Chats_List />
				{/if}
			</div>
		</div>

		<div class="column_fluid">
			{#if chats.selected}
				<Contextmenu_Chat chat={chats.selected}>
					<Chat_View chat={chats.selected} />
				</Contextmenu_Chat>
			{:else if chats.items.size}
				<div class="display_flex align_items_center justify_content_center h_100 flex_1">
					<div class="p_md text_align_center">
						<p>
							select a chat from the list,
							<button
								type="button"
								class="inline color_d"
								onclick={() => chats.add(undefined, true)}>create a new chat</button
							>, or
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
				</div>
			{:else}
				<div class="box h_100">
					<p>
						no chats yet,
						<button type="button" class="inline color_d" onclick={() => chats.add(undefined, true)}
							>create a new chat</button
						>?
					</p>
				</div>
			{/if}
		</div>
	</div>
</Contextmenu_Chats>
