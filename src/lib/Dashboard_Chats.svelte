<script lang="ts">
	import {slide} from 'svelte/transition';
	import Chat_View from '$lib/Chat_View.svelte';
	import {GLYPH_CHAT} from '$lib/constants.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();
</script>

<div class="dashboard_chats p_sm">
	<!-- TODO, show the counts of active items for each of the model selector buttons in a snippet here -->
	<div class="panel p_sm">
		<button class="w_100 justify_content_start" type="button" onclick={() => zzz.add_chat()}>
			+ new chat
		</button>
		<menu class="unstyled">
			{#each zzz.chats as chat (chat.id)}
				<button
					type="button"
					class:selected={chat.id === zzz.selected_chat_id}
					onclick={() => zzz.select_chat(chat)}
					transition:slide
				>
					<div class="font_weight_400">
						<span class="mr_xs2">{GLYPH_CHAT}</span>
						<small>Chat {chat.id}</small>
					</div>
				</button>
			{/each}
		</menu>
	</div>
	<!-- TODO select view (tabs?) -->
	{#if zzz.inited_models && zzz.selected_chat}
		<Chat_View chat={zzz.selected_chat} />
	{/if}
</div>

<style>
	.dashboard_chats {
		display: flex;
		align-items: start;
		gap: var(--space_md);
	}
</style>
