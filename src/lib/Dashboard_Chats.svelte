<script lang="ts">
	import {random_item} from '@ryanatkn/belt/random.js';

	import Chat_List from '$lib/Chat_List.svelte';
	import Chat_View from '$lib/Chat_View.svelte';
	import Chat_Contextmenu from '$lib/Chat_Contextmenu.svelte';
	import {GLYPH_ADD, GLYPH_SORT} from '$lib/glyphs.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import Glyph from '$lib/Glyph.svelte';
	import Chats_Contextmenu from '$lib/Chats_Contextmenu.svelte';
	import Tutorial_For_Database from '$lib/Tutorial_For_Database.svelte';
	import Tutorial_For_Chats from '$lib/Tutorial_For_Chats.svelte';

	const app = frontend_context.get();
	const {chats} = app;

	// TODO BLOCK this needs to have an error if no backend capability
</script>

<Chats_Contextmenu attrs={{class: 'display_flex w_100 h_100'}}>
	<div class="column_fixed">
		<div class="py_sm pr_sm">
			<div class="row gap_xs2 mb_xs pl_xs2">
				<button
					class="plain flex_1 justify_content_start"
					type="button"
					onclick={() => chats.add(undefined, true)}
				>
					<Glyph glyph={GLYPH_ADD} />&nbsp; new chat
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
				<Chat_List />
			{/if}
		</div>
		<Tutorial_For_Database />
		<Tutorial_For_Chats />
	</div>

	<div class="column_fluid">
		{#if chats.selected}
			<Chat_Contextmenu chat={chats.selected}>
				<Chat_View chat={chats.selected} />
			</Chat_Contextmenu>
		{:else if chats.items.size}
			<div class="display_flex align_items_center justify_content_center h_100 flex_1">
				<div class="p_md text_align_center">
					<p>
						select a chat from the list,
						<button type="button" class="inline color_d" onclick={() => chats.add(undefined, true)}
							>create a new chat</button
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
</Chats_Contextmenu>
