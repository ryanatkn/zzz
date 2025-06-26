<script lang="ts">
	import {slide} from 'svelte/transition';
	import {tick} from 'svelte';
	import {swallow} from '@ryanatkn/belt/dom.js';

	import Glyph from '$lib/Glyph.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {Chat} from '$lib/chat.svelte.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import {GLYPH_TAPE, GLYPH_CHAT, GLYPH_DELETE, GLYPH_VIEW} from '$lib/glyphs.js';
	import Tape_List from '$lib/Tape_List.svelte';
	import Chat_View_Simple from '$lib/Chat_View_Simple.svelte';
	import Chat_View_Multi from '$lib/Chat_View_Multi.svelte';
	import Toggle_Button from '$lib/Toggle_Button.svelte';
	import Chat_Initializer from '$lib/Chat_Initializer.svelte';
	import Chat_Tape_Add_By_Model from '$lib/Chat_Tape_Add_By_Model.svelte';
	import Chat_Tape_Manage_By_Tag from '$lib/Chat_Tape_Manage_By_Tag.svelte';

	const app = frontend_context.get();
	const {chats} = app;

	interface Props {
		chat: Chat;
	}

	const {chat}: Props = $props();

	const tape_count = $derived(chat.tapes.length);

	// TODO BLOCK do this in the prompt view
	// TODO BLOCK consider hoisting this state to the chat, maybe in a new helper class
	let is_editing_name = $state(false);
	let edited_name = $state('');
	let name_input_el: HTMLInputElement | undefined = $state();

	const save_name = () => {
		if (!edited_name.trim()) {
			is_editing_name = false;
			return;
		}
		chat.name = edited_name.trim();
		is_editing_name = false;
	};

	// TODO clicking tapes should select them, if none selected then default to the first

	// TODO add `presets` section to the top with the custom buttons/sets (accessible via contextmenu)
	// TODO custom buttons section - including quick local, smartest all, all, etc - custom buttons to do common things, compose them with buttons like "fill all" or "fill with tag" or at least drag
</script>

<div class="flex_1 h_100 display_flex align_items_start">
	<div class="column_fixed">
		{#if chat}
			<section class="column_section" transition:slide>
				<!-- TODO needs work -->
				<div class="font_size_lg display_flex align_items_center gap_xs">
					<Glyph glyph={GLYPH_CHAT} />
					{#if is_editing_name}
						<input
							type="text"
							class="plain"
							bind:this={name_input_el}
							bind:value={edited_name}
							onblur={save_name}
							onkeydown={(e) => {
								if (e.key === 'Enter') {
									swallow(e);
									save_name();
								} else if (e.key === 'Escape') {
									swallow(e);
									is_editing_name = false;
									edited_name = '';
								}
							}}
						/>
					{:else}
						<button
							type="button"
							class="plain flex_1 font_weight_400 justify_content_start"
							onclick={() => {
								is_editing_name = true;
								edited_name = chat.name;
								void tick().then(() => name_input_el?.select());
							}}
							title="Click to edit chat name"
						>
							{chat.name}
						</button>
					{/if}
				</div>
				<div class="column">
					<small title={chat.created_formatted_datetime}
						>created {chat.created_formatted_short_date}</small
					>
				</div>
				<div class="row gap_xs py_xs">
					<Confirm_Button
						onconfirm={() => chat.id && chats.remove(chat.id)}
						position="right"
						attrs={{
							title: `delete chat "${chat.name}"`,
							class: 'plain icon_button',
						}}
					>
						<Glyph glyph={GLYPH_DELETE} />
						{#snippet popover_button_content()}<Glyph glyph={GLYPH_DELETE} />{/snippet}
					</Confirm_Button>
					{#if tape_count}
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

		{#if tape_count && (chat.view_mode !== 'simple' || tape_count > 1)}
			<section class="column_section">
				<header class="mt_0 mb_lg font_size_lg display_flex justify_content_space_between">
					<span><Glyph glyph={GLYPH_TAPE} /> tapes</span><span>{tape_count}</span>
				</header>
				<Tape_List {chat} />
			</section>
			<!-- TODO consider a UX that lets users pin arbitrary prompts/bits/etc to each chat -->
		{/if}

		{#if chat.view_mode === 'multi'}
			<section class="column_section">
				<Chat_Tape_Add_By_Model {chat} />
			</section>
			<section class="column_section">
				<Chat_Tape_Manage_By_Tag {chat} />
			</section>
		{/if}
	</div>

	{#if !tape_count}
		<div class="column_fluid p_md">
			<Chat_Initializer {chat} oninit={(chat_id) => chats.navigate_to(chat_id)} />
		</div>
	{:else if chat.view_mode === 'simple'}
		<Chat_View_Simple {chat} tape={chat.current_tape} />
	{:else}
		<Chat_View_Multi {chat} />
	{/if}
</div>
