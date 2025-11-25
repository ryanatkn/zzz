<script lang="ts">
	import {random_item} from '@ryanatkn/belt/random.js';
	import PendingAnimation from '@ryanatkn/fuz/PendingAnimation.svelte';
	import {onMount} from 'svelte';

	import ChatList from '$lib/ChatList.svelte';
	import ChatView from '$lib/ChatView.svelte';
	import ChatContextmenu from '$lib/ChatContextmenu.svelte';
	import {GLYPH_ADD, GLYPH_SORT} from '$lib/glyphs.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import Glyph from '$lib/Glyph.svelte';
	import ChatsContextmenu from '$lib/ChatsContextmenu.svelte';
	import TutorialForDatabase from '$lib/TutorialForDatabase.svelte';
	import TutorialForChats from '$lib/TutorialForChats.svelte';
	import ErrorMessage from '$lib/ErrorMessage.svelte';

	const app = frontend_context.get();
	const {chats, capabilities} = app;

	onMount(() => {
		void capabilities.init_backend_check();
	});
</script>

<ChatsContextmenu attrs={{class: 'display_flex width_100 height_100'}}>
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
				<ChatList />
			{/if}
		</div>
		<TutorialForDatabase />
		<TutorialForChats />

		{#if capabilities.backend_available === false}
			<div class="box mt_lg">
				<ErrorMessage>
					<p>
						Backend is not available. Chats require a backend connection to communicate with AI
						models.
					</p>
					<p class="mt_md">
						<button
							type="button"
							disabled={capabilities.backend.status === 'pending'}
							onclick={() => capabilities.check_backend()}
						>
							retry connection
						</button>
					</p>
				</ErrorMessage>
			</div>
		{:else if capabilities.backend_available === null || capabilities.backend_available === undefined}
			<div class="box mt_lg">
				<blockquote>
					checking backend connection <PendingAnimation inline />
				</blockquote>
			</div>
		{/if}
	</div>

	<div class="column_fluid">
		{#if chats.selected}
			<ChatContextmenu chat={chats.selected}>
				<ChatView chat={chats.selected} />
			</ChatContextmenu>
		{:else if chats.items.size}
			<div class="box height_100 flex_1">
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
			<div class="box height_100">
				<p>
					no chats yet,
					<button type="button" class="inline color_d" onclick={() => chats.add(undefined, true)}
						>create a new chat</button
					>?
				</p>
			</div>
		{/if}
	</div>
</ChatsContextmenu>
