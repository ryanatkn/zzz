<script lang="ts">
	import {slide} from 'svelte/transition';
	import Details from '@ryanatkn/fuz/Details.svelte';

	import Glyph from '$lib/Glyph.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {Chat} from '$lib/chat.svelte.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import {GLYPH_THREAD, GLYPH_CHAT, GLYPH_DELETE, GLYPH_VIEW} from '$lib/glyphs.js';
	import Thread_List from '$lib/Thread_List.svelte';
	import Chat_View_Simple from '$lib/Chat_View_Simple.svelte';
	import Chat_View_Multi from '$lib/Chat_View_Multi.svelte';
	import Toggle_Button from '$lib/Toggle_Button.svelte';
	import Chat_Initializer from '$lib/Chat_Initializer.svelte';
	import Chat_Thread_Add_By_Model from '$lib/Chat_Thread_Add_By_Model.svelte';
	import Chat_Thread_Manage_By_Tag from '$lib/Chat_Thread_Manage_By_Tag.svelte';
	import Editable_Text from '$lib/Editable_Text.svelte';

	const app = frontend_context.get();
	const {chats} = app;

	const {
		chat,
	}: {
		chat: Chat;
	} = $props();

	const thread_count = $derived(chat.threads.length);

	// TODO the add by model stuff is too noisy/overwhelming, needs some redesign

	// TODO add `presets` section to the top with the custom buttons/sets (accessible via contextmenu)
	// TODO custom buttons section - including quick local, smartest all, all, etc - custom buttons to do common things, compose them with buttons like "fill all" or "fill with tag" or at least drag
</script>

<div class="flex_1 height_100 display_flex align_items_start">
	<div class="column_fixed">
		{#if chat}
			<section class="column_section" transition:slide>
				<!-- TODO needs work -->
				<div class="font_size_lg display_flex align_items_center">
					<Glyph glyph={GLYPH_CHAT} />
					<Editable_Text bind:value={chat.name} />
				</div>
				<div class="row">
					<small class="flex_1" title={chat.created_formatted_datetime}
						>created {chat.created_formatted_short_date}</small
					>
					<div class="row gap_xs py_xs">
						{#if thread_count}
							<Toggle_Button
								bind:active={
									() => chat.view_mode === 'simple',
									(active) => (chat.view_mode = active ? 'simple' : 'multi')
								}
								active_content="simple"
								inactive_content="multi"
								class="plain compact"
								title="toggle chat to ${chat.view_mode === 'multi' ? 'simple' : 'multi'} view"
							>
								<Glyph glyph={GLYPH_VIEW} class="mr_xs" />
							</Toggle_Button>
						{/if}
						<Confirm_Button
							onconfirm={() => chat.id && chats.remove(chat.id)}
							title="delete chat {'"' + chat.name + '"'}"
							class="plain icon_button"
						>
							<Glyph glyph={GLYPH_DELETE} />
							{#snippet popover_button_content()}<Glyph glyph={GLYPH_DELETE} />{/snippet}
						</Confirm_Button>
					</div>
				</div>
			</section>
		{/if}

		{#if thread_count && (chat.view_mode !== 'simple' || thread_count > 1)}
			<section class="column_section">
				<header
					class="mt_0 mb_lg font_size_lg display_flex justify_content_space_between"
					title="threads are the individual threads of conversation in a chat -- each chat can have many threads, comprising its history"
				>
					<span><Glyph glyph={GLYPH_THREAD} /> threads</span><span>{thread_count}</span>
				</header>
				<Thread_List {chat} />
			</section>
			<!-- TODO consider a UX that lets users pin arbitrary prompts/parts/etc to each chat -->
		{/if}

		{#if chat.view_mode === 'multi'}
			<Details>
				{#snippet summary()}manage threads{/snippet}
				<section class="column_section">
					<Chat_Thread_Add_By_Model {chat} />
				</section>
				<section class="column_section">
					<Chat_Thread_Manage_By_Tag {chat} />
				</section>
			</Details>
		{/if}
	</div>

	{#if !thread_count}
		<div class="column_fluid p_md">
			<Chat_Initializer {chat} oninit={(chat_id) => chats.navigate_to(chat_id)} />
		</div>
	{:else if chat.view_mode === 'simple'}
		<Chat_View_Simple {chat} thread={chat.current_thread} />
	{:else}
		<Chat_View_Multi {chat} />
	{/if}
</div>
