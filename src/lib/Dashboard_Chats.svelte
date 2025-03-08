<script lang="ts">
	import {random_item} from '@ryanatkn/belt/random.js';
	import {fade} from 'svelte/transition';

	import Chat_View from '$lib/Chat_View.svelte';
	import Nav_Link from '$lib/Nav_Link.svelte';
	import {GLYPH_CHAT} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {Reorderable} from '$lib/reorderable.svelte.js';

	const zzz = zzz_context.get();

	const reorderable = new Reorderable();
</script>

<div class="flex w_100 h_100">
	<!-- TODO show the selected chat's info, if any -->
	<!-- TODO, show the counts of active items for each of the model selector buttons in a snippet here -->
	<div class="column_fixed">
		<div class="p_sm">
			<button
				class="plain w_100 justify_content_start"
				type="button"
				onclick={() => zzz.chats.add()}
			>
				+ new chat
			</button>
			{#if zzz.chats.items.length}
				<menu
					class="unstyled mt_sm"
					use:reorderable.list={{
						onreorder: (from_index, to_index) => zzz.chats.reorder_chats(from_index, to_index),
					}}
				>
					{#each zzz.chats.items as chat, i (chat.id)}
						<!-- TODO change to href from onclick -->
						<li use:reorderable.item={{index: i}}>
							<Nav_Link
								href="#TODO"
								selected={chat.id === zzz.chats.selected_id}
								attrs={{
									class: 'justify_content_space_between',
									style: 'min-height: 0;',
									onclick: () => zzz.chats.select(chat.id),
								}}
							>
								<div>
									<span class="mr_xs2">{GLYPH_CHAT}</span>
									<span>{chat.name}</span>
								</div>
								{#if chat.tapes.length}<small>{chat.tapes.length}</small>{/if}
							</Nav_Link>
						</li>
					{/each}
				</menu>
			{/if}
		</div>
	</div>
	<!-- TODO select view (tabs?) -->
	{#if zzz.inited_models}
		{#if zzz.chats.selected}
			<Chat_View chat={zzz.chats.selected} />
		{:else}
			<div class="flex align_items_center justify_content_center h_100 flex_1" in:fade>
				<p>
					Select a chat from the list or <button
						type="button"
						class="inline color_d"
						onclick={() => {
							zzz.chats.add();
						}}>create one</button
					>
					or take a
					<button
						type="button"
						class="inline color_f"
						onclick={() => {
							zzz.chats.select(random_item(zzz.chats.items).id);
						}}>random walk</button
					>?
				</p>
			</div>
		{/if}
	{/if}
</div>
