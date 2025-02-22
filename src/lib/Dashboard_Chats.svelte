<script lang="ts">
	import {slide} from 'svelte/transition';
	import Chat_View from '$lib/Chat_View.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {GLYPH_CHAT} from '$lib/constants.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();
</script>

<div class="dashboard_chats">
	<!-- TODO show the selected chat's info, if any -->
	<!-- TODO, show the counts of active items for each of the model selector buttons in a snippet here -->
	<div class="panel p_sm">
		{#if zzz.selected_chat}
			<div
				class="p_sm shadow_color_a radius_xs border_solid border_width_2 border_color_a"
				transition:slide
			>
				<div class="column">
					<!-- TODO needs work -->
					<div>Chat {zzz.selected_chat.id}</div>
					<div>
						{zzz.selected_chat.tapes.length} tape{#if zzz.selected_chat.tapes.length !== 1}s{/if}
					</div>
					<div class="flex justify_content_end">
						<Confirm_Button
							onclick={() => zzz.selected_chat && zzz.remove_chat(zzz.selected_chat)}
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
				<button
					type="button"
					class:selected={chat.id === zzz.selected_chat_id}
					onclick={() => zzz.select_chat(chat.id)}
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
		padding: var(--space_sm);
	}
</style>
