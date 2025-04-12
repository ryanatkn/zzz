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
</script>

<div class="flex w_100 h_100">
	<!-- TODO show the selected chat's info, if any -->
	<div class="column_fixed">
		<div class="py_sm pr_sm">
			<div class="row">
				<button
					class="plain flex_1 justify_content_start"
					type="button"
					onclick={() => zzz.chats.add()}
				>
					{GLYPH_ADD} new chat
				</button>
				<button
					type="button"
					class="plain compact selectable deselectable"
					class:selected={zzz.chats.show_sort_controls}
					title="toggle sort controls"
					onclick={() => zzz.chats.toggle_sort_controls()}
				>
					<Glyph icon={GLYPH_SORT} />
				</button>
			</div>
			{#if zzz.chats.items.size}
				<Chats_List />
			{/if}
		</div>
	</div>
	{#if zzz.chats.selected}
		<Contextmenu_Chat chat={zzz.chats.selected}>
			<Chat_View chat={zzz.chats.selected} />
		</Contextmenu_Chat>
	{:else if zzz.chats.items.size}
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
						zzz.chats.select(random_item(zzz.chats.ordered_items).id);
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
