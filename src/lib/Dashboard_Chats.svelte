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
		{#if zzz.chats.selected}
			<div class="p_sm fg_1 radius_xs2" transition:slide>
				<div class="column">
					<!-- TODO needs work -->
					<div class="size_lg">{zzz.chats.selected.name}</div>
					<small>{zzz.chats.selected.id}</small>
					<small>
						{zzz.chats.selected.tapes.length}
						tape{#if zzz.chats.selected.tapes.length !== 1}s{/if}
					</small>
					<small>created {format(zzz.chats.selected.created, 'MMM d, p')}</small>
					<div class="flex justify_content_end">
						<Confirm_Button
							onclick={() => zzz.chats.selected && zzz.chats.remove(zzz.chats.selected)}
							button_attrs={{title: `remove Chat ${zzz.chats.selected.id}`}}
						/>
					</div>
				</div>
			</div>
		{/if}
		<button class="plain w_100 justify_content_start" type="button" onclick={() => zzz.chats.add()}>
			+ new chat
		</button>
		<menu class="unstyled">
			{#each zzz.chats.items as chat (chat.id)}
				<!-- TODO change to href from onclick -->
				<Nav_Link
					href="#TODO"
					selected={chat.id === zzz.chats.selected_id}
					attrs={{
						type: 'button',
						class: 'justify_content_space_between',
						style: 'min-height: 0;',
						onclick: () => zzz.chats.select(chat.id),
					}}
				>
					<div>
						<span class="mr_xs2">{GLYPH_CHAT}</span>
						<small>{chat.name}</small>
					</div>
					{#if chat.tapes.length}<small>{chat.tapes.length}</small>{/if}
				</Nav_Link>
			{/each}
		</menu>
	</div>
	<!-- TODO select view (tabs?) -->
	{#if zzz.inited_models && zzz.chats.selected}
		<Chat_View chat={zzz.chats.selected} />
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
