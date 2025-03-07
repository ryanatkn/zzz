<script lang="ts">
	import {slide} from 'svelte/transition';
	import {format} from 'date-fns';

	import Chat_View from '$lib/Chat_View.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Nav_Link from '$lib/Nav_Link.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {GLYPH_CHAT} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {Reorderable} from '$lib/reorderable.svelte.js';

	const zzz = zzz_context.get();

	const reorderable = new Reorderable();

	// TODO BLOCK columns with overflow, not the whole page
</script>

<div class="flex align_items_start">
	<!-- TODO show the selected chat's info, if any -->
	<!-- TODO, show the counts of active items for each of the model selector buttons in a snippet here -->
	<div class="p_sm width_sm">
		<div class="panel">
			{#if zzz.chats.selected}
				<div class="p_sm" transition:slide>
					<div class="column bg p_sm radius_xs2">
						<!-- TODO needs work -->
						<div class="size_lg">
							<Glyph_Icon icon={GLYPH_CHAT} />
							{zzz.chats.selected.name}
						</div>
						<small>{zzz.chats.selected.id}</small>
						<small>
							{zzz.chats.selected.tapes.length}
							tape{#if zzz.chats.selected.tapes.length !== 1}s{/if}
						</small>
						<small>created {format(zzz.chats.selected.created, 'MMM d, p')}</small>
						<div class="flex justify_content_end">
							<Confirm_Button
								onclick={() => zzz.chats.selected && zzz.chats.remove(zzz.chats.selected)}
								attrs={{title: `remove Chat ${zzz.chats.selected.id}`}}
							/>
						</div>
					</div>
				</div>
			{/if}
			<div class="p_sm">
				<button
					class="plain w_100 justify_content_start my_sm"
					type="button"
					onclick={() => zzz.chats.add()}
				>
					+ new chat
				</button>
				<menu
					class="unstyled"
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
			</div>
		</div>
	</div>
	<!-- TODO select view (tabs?) -->
	{#if zzz.inited_models && zzz.chats.selected}
		<Chat_View chat={zzz.chats.selected} />
	{/if}
</div>
