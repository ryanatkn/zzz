<script lang="ts">
	import {slide} from 'svelte/transition';

	import Glyph from '$lib/Glyph.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {Chat} from '$lib/chat.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_TAPE, GLYPH_BIT, GLYPH_PROMPT, GLYPH_CHAT, GLYPH_DELETE} from '$lib/glyphs.js';
	import Prompt_List from '$lib/Prompt_List.svelte';
	import Bit_List from '$lib/Bit_List.svelte';
	import Tape_List from '$lib/Tape_List.svelte';
	import Chat_View_Simple from '$lib/Chat_View_Simple.svelte';
	import Chat_View_Multi from '$lib/Chat_View_Multi.svelte';
	import Toggle_Button from '$lib/Toggle_Button.svelte';
	import type {Tape} from '$lib/tape.svelte.js';

	const zzz = zzz_context.get();

	interface Props {
		chat: Chat;
	}

	const {chat}: Props = $props();

	// TODO BLOCK this needs to be persisted state
	if (chat.tapes.length === 0) {
		const initial_model_names = [
			'llama3.2:1b',
			'llama3.2:3b',
			'gemma3:1b',
			'gemma3:4b',
			'qwen2.5:0.5b',
			'qwen2.5:1.5b',
		];
		const initial_models = zzz.models.filter_by_names(initial_model_names);
		if (initial_models) {
			for (const initial_model of initial_models) {
				chat.add_tape(initial_model);
			}
		} else {
			console.error(`model not found: ${zzz.bots.namerbot}`);
		}
	}

	const first_tape = $derived(chat.tapes[0] as Tape | undefined);
	const selected_chat = $derived(zzz.chats.selected);

	// TODO add `presets`  section to the top with the custom buttons/sets (accessible via contextmenu)
	// TODO custom buttons section - including quick local, smartest all, all, etc - custom buttons to do common things, compose them with a textarea with buttons like "fill all" or "fill with tag" or at least drag
</script>

<div class="flex_1 h_100 flex align_items_start">
	<div class="column_fixed">
		{#if selected_chat}
			<section class="column_section" transition:slide>
				<!-- TODO needs work -->
				<div class="flex justify_content_space_between">
					<div class="size_lg">
						<Glyph icon={GLYPH_CHAT} />
						{selected_chat.name}
					</div>
				</div>
				<div class="column font_mono">
					<small title={selected_chat.created_formatted_date}
						>created {selected_chat.created_formatted_short_date}</small
					>
					<small>
						{selected_chat.tapes.length}
						tape{#if selected_chat.tapes.length !== 1}s{/if}
					</small>
				</div>
				<div class="row">
					<Confirm_Button
						onconfirm={() => zzz.chats.selected_id && zzz.chats.remove(zzz.chats.selected_id)}
						position="right"
						attrs={{title: `delete chat "${selected_chat.name}"`, class: 'plain'}}
					>
						{GLYPH_DELETE}
						{#snippet popover_button_content()}{GLYPH_DELETE}{/snippet}
					</Confirm_Button>
					<Toggle_Button
						active={chat.view_mode === 'simple'}
						active_content="simple"
						inactive_content="multi"
						ontoggle={(active) => (chat.view_mode = active ? 'simple' : 'multi')}
						attrs={{
							class: 'plain',
							title: `toggle to ${chat.view_mode === 'multi' ? 'simple' : 'multi'} view`,
						}}
					/>
				</div>
			</section>
		{/if}
		{#if chat.view_mode !== 'simple'}
			<section class="column_section">
				<header class="mt_0 mb_lg size_lg"><Glyph icon={GLYPH_TAPE} /> tapes</header>
				<Tape_List {chat} />
			</section>
			<section class="column_section">
				<header class="mt_0 mb_lg size_lg"><Glyph icon={GLYPH_PROMPT} /> prompts</header>
				<Prompt_List {chat} />
			</section>
			<!-- TODO maybe show `Bit_List` with the `prompt bits` header here in -->
			<section class="column_section">
				<header class="mt_0 mb_lg size_lg"><Glyph icon={GLYPH_BIT} /> all bits</header>
				<Bit_List bits={chat.bits_array} />
			</section>
		{/if}
	</div>

	{#if chat.view_mode === 'simple'}
		<Chat_View_Simple {chat} tape={first_tape} />
	{:else}
		<Chat_View_Multi {chat} />
	{/if}
</div>
