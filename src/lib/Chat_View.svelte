<script lang="ts">
	import {slide} from 'svelte/transition';

	import Glyph from '$lib/Glyph.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {Chat} from '$lib/chat.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_TAPE, GLYPH_CHAT, GLYPH_DELETE, GLYPH_VIEW} from '$lib/glyphs.js';
	import Tape_List from '$lib/Tape_List.svelte';
	import Chat_View_Simple from '$lib/Chat_View_Simple.svelte';
	import Chat_View_Multi from '$lib/Chat_View_Multi.svelte';
	import Toggle_Button from '$lib/Toggle_Button.svelte';
	import type {Tape} from '$lib/tape.svelte.js';
	import Chat_Initializer from '$lib/Chat_Initializer.svelte';

	const zzz = zzz_context.get();
	const {chats} = zzz;

	interface Props {
		chat: Chat;
	}

	const {chat}: Props = $props();

	const first_tape = $derived(chat.tapes[0] as Tape | undefined);
	const selected_chat = $derived(chats.selected);
	const empty_chat = $derived(chat.tapes.length === 0);

	// TODO BLOCK clicking tapes should select them, if none selected then default to the first

	// TODO add `presets` section to the top with the custom buttons/sets (accessible via contextmenu)
	// TODO custom buttons section - including quick local, smartest all, all, etc - custom buttons to do common things, compose them with buttons like "fill all" or "fill with tag" or at least drag
</script>

<div class="flex_1 h_100 flex align_items_start">
	<div class="column_fixed">
		{#if selected_chat}
			<section class="column_section" transition:slide>
				<!-- TODO needs work -->
				<div class="flex justify_content_space_between">
					<div class="size_lg">
						<Glyph glyph={GLYPH_CHAT} />
						{selected_chat.name}
					</div>
				</div>
				<div class="column">
					<small title={selected_chat.created_formatted_date}
						>created {selected_chat.created_formatted_short_date}</small
					>
					<small>
						{selected_chat.tapes.length}
						tape{#if selected_chat.tapes.length !== 1}s{/if}
					</small>
				</div>
				<div class="row gap_xs py_xs">
					<Confirm_Button
						onconfirm={() => chats.selected_id && chats.remove(chats.selected_id)}
						position="right"
						attrs={{
							title: `delete chat "${selected_chat.name}"`,
							class: 'plain icon_button',
						}}
					>
						<Glyph glyph={GLYPH_DELETE} />
						{#snippet popover_button_content()}<Glyph glyph={GLYPH_DELETE} />{/snippet}
					</Confirm_Button>
					{#if selected_chat.tapes.length}
						<Toggle_Button
							active={chat.view_mode === 'simple'}
							active_content="multi"
							inactive_content="simple"
							ontoggle={(active) => (chat.view_mode = active ? 'simple' : 'multi')}
							attrs={{
								class: 'plain compact',
								title: `toggle chat to ${chat.view_mode === 'multi' ? 'simple' : 'multi'} view`,
							}}
						>
							<Glyph glyph={GLYPH_VIEW} attrs={{class: 'mr_xs'}} />
						</Toggle_Button>
					{/if}
				</div>
			</section>
		{/if}

		{#if !empty_chat && (chat.view_mode !== 'simple' || chat.tapes.length > 1)}
			<section class="column_section">
				<header class="mt_0 mb_lg size_lg"><Glyph glyph={GLYPH_TAPE} /> tapes</header>
				<Tape_List {chat} />
			</section>
			<!-- TODO consider a UX that lets users pin arbitrary prompts/bits/etc to each chat -->
		{/if}
	</div>

	{#if empty_chat}
		<div class="column_fluid p_md">
			<Chat_Initializer {chat} oninit={(chat_id) => chats.navigate_to(chat_id)} />
		</div>
	{:else if chat.view_mode === 'simple'}
		<Chat_View_Simple {chat} tape={first_tape} />
	{:else}
		<Chat_View_Multi {chat} />
	{/if}
</div>
