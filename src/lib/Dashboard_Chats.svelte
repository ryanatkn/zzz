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
	<div class="panel p_sm width_sm">
		{#if zzz.selected_chat}
			<div class="p_sm radius_xs2 border_solid border_width_2 border_color_4" transition:slide>
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
		<button
			class="plain w_100 justify_content_start radius_xs2"
			type="button"
			onclick={() => zzz.add_chat()}
		>
			+ new chat
		</button>
		<menu class="unstyled">
			{#each zzz.chats as chat (chat.id)}
				<button
					type="button"
					class="w_100 justify_content_space_between px_sm py_xs2 radius_xs2 font_weight_500"
					style:min-height="0"
					class:selected={chat.id === zzz.selected_chat_id}
					onclick={() => zzz.select_chat(chat.id)}
					transition:slide
				>
					<div>
						<span class="mr_xs2">{GLYPH_CHAT}</span>
						<small>Chat {chat.id}</small>
					</div>
					{#if chat.tapes.length}<small>{chat.tapes.length}</small>{/if}
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
