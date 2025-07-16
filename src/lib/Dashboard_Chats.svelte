<script lang="ts">
	import {random_item} from '@ryanatkn/belt/random.js';
	import {blur, scale} from 'svelte/transition';

	import Chats_List from '$lib/Chat_List.svelte';
	import Chat_View from '$lib/Chat_View.svelte';
	import Chat_Contextmenu from '$lib/Chat_Contextmenu.svelte';
	import {GLYPH_ADD, GLYPH_SORT} from '$lib/glyphs.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import Glyph from '$lib/Glyph.svelte';
	import Chats_Contextmenu from '$lib/Chats_Contextmenu.svelte';
	import External_Link from '$lib/External_Link.svelte';

	const app = frontend_context.get();
	const {chats} = app;
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
				<Chats_List />
			{/if}
		</div>
		{#if app.prompts.tutorial_for_chats}
			<div class="pt_lg" out:blur={{duration: 1000}}>
				<!-- TODO is there no end value param? how to do this better?
				 it stays in the dom the whole duration (causes the parent to as well),
				 which will cause layout issues if anything is placed after it in the DOM -->
				<aside out:scale={{duration: 44000}}>
					<p>
						⚠️ This is a an early prototype and your data is not saved yet -- soon it will be
						persisted to a local Postgres or pglite database. (<External_Link
							href="https://github.com/ryanatkn/zzz/issues/7">issue 7</External_Link
						>)
					</p>
					<p>
						It currently supports chatting with local models via Ollama, and if you bring your own
						API key, it supports basic text chat with ChatGPT, Claude, and Gemini.
					</p>
					<button
						type="button"
						class="compact"
						onclick={() => {
							app.prompts.tutorial_for_chats = false;
						}}>ok</button
					>
				</aside>
			</div>
		{/if}
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
