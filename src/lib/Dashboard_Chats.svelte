<script lang="ts">
	import {slide} from 'svelte/transition';
	import {format} from 'date-fns';

	import Chat_View from '$lib/Chat_View.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Nav_Link from '$lib/Nav_Link.svelte';
	import {GLYPH_CHAT} from '$lib/constants.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();
</script>

<div class="dashboard_chats">
	<!-- TODO show the selected chat's info, if any -->
	<!-- TODO, show the counts of active items for each of the model selector buttons in a snippet here -->
	<div class="panel p_sm width_sm">
		{#if zzz.selected_chat}
			<div class="p_sm fg_1 radius_xs2" transition:slide>
				<div class="column">
					<!-- TODO needs work -->
					<div class="size_lg">Chat {zzz.selected_chat.id}</div>
					<small>
						{zzz.selected_chat.tapes.length}
						tape{#if zzz.selected_chat.tapes.length !== 1}s{/if}
					</small>
					<small>created {format(zzz.selected_chat.created, 'MMM d, p')}</small>
					<div class="flex justify_content_end">
						<Confirm_Button
							onclick={() => zzz.selected_chat && zzz.remove_chat(zzz.selected_chat)}
							button_attrs={{title: `remove Chat ${zzz.selected_chat.id}`}}
						/>
					</div>
				</div>
			</div>
		{/if}
		<button class="plain w_100 justify_content_start" type="button" onclick={() => zzz.add_chat()}>
			+ new chat
		</button>
		<menu class="unstyled">
			{#each zzz.chats as chat (chat.id)}
				<!-- TODO change to href from onclick -->
				<Nav_Link
					href="#TODO"
					selected={chat.id === zzz.selected_chat_id}
					attrs={{
						type: 'button',
						style: 'min-height: 0;',
						onclick: () => zzz.select_chat(chat.id),
					}}
				>
					<div>
						<span class="mr_xs2">{GLYPH_CHAT}</span>
						<small>Chat {chat.id}</small>
					</div>
					{#if chat.tapes.length}<small>{chat.tapes.length}</small>{/if}
				</Nav_Link>
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
		padding: var(--space_sm);
	}
</style>
