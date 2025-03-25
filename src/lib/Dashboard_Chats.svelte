<script lang="ts">
	import {random_item} from '@ryanatkn/belt/random.js';
	import {fade} from 'svelte/transition';

	import Chat_View from '$lib/Chat_View.svelte';
	import Nav_Link from '$lib/Nav_Link.svelte';
	import Contextmenu_Chat from '$lib/Contextmenu_Chat.svelte';
	import {GLYPH_CHAT, GLYPH_ADD} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {Reorderable} from '$lib/reorderable.svelte.js';

	const zzz = zzz_context.get();

	const reorderable = new Reorderable();

	$inspect('zzz.chats.items.all.length', zzz.chats.items.all.length);
</script>

<div class="flex w_100 h_100">
	<!-- TODO show the selected chat's info, if any -->
	<div class="column_fixed">
		<div class="py_sm pr_sm">
			<button
				class="plain w_100 justify_content_start"
				type="button"
				onclick={() => zzz.chats.add()}
			>
				{GLYPH_ADD} new chat
			</button>
			{#if zzz.chats.items.all.length}
				<menu
					class="unstyled mt_sm"
					use:reorderable.list={{
						onreorder: (from_index, to_index) => zzz.chats.reorder_chats(from_index, to_index),
					}}
				>
					{#each zzz.chats.items.all as chat, i (chat.id)}
						<!-- TODO change to href from onclick -->
						<li use:reorderable.item={{index: i}}>
							<Contextmenu_Chat {chat}>
								<Nav_Link
									href="?chat={chat.id}"
									selected={chat.id === zzz.chats.selected_id}
									attrs={{
										class: 'justify_content_space_between',
										style: 'min-height: 0;',
									}}
								>
									<div>
										<span class="mr_xs2">{GLYPH_CHAT}</span>
										<span>{chat.name}</span>
									</div>
									{#if chat.tapes.length}<small>{chat.tapes.length}</small>{/if}
								</Nav_Link>
							</Contextmenu_Chat>
						</li>
					{/each}
				</menu>
			{/if}
		</div>
	</div>
	{#if zzz.chats.selected}
		<Contextmenu_Chat chat={zzz.chats.selected}>
			<Chat_View chat={zzz.chats.selected} />
		</Contextmenu_Chat>
	{:else if zzz.chats.items.all.length}
		<div class="flex align_items_center justify_content_center h_100 flex_1" in:fade>
			<p>
				Select a chat from the list or <button
					type="button"
					class="inline color_d"
					onclick={() => {
						zzz.chats.add();
					}}>create one</button
				>
				or
				<button
					type="button"
					class="inline color_f"
					onclick={() => {
						zzz.chats.select(random_item(zzz.chats.items.all).id);
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
					onclick={() => {
						zzz.chats.add();
					}}>create one</button
				>?
			</p>
		</div>
	{/if}
</div>
