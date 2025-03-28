<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Chat} from '$lib/chat.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_CHAT, GLYPH_DELETE, GLYPH_EDIT, GLYPH_PROMPT, GLYPH_REMOVE} from '$lib/glyphs.js';
	import Contextmenu_Copy_To_Clipboard from '$lib/Contextmenu_Copy_To_Clipboard.svelte';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		chat: Chat;
	}

	const {chat, ...rest}: Props = $props();

	const zzz = zzz_context.get();

	// TODO BLOCK duplicate has a bug on selected chat?

	// TODO BLOCK `add tape` button that uses a new Tape_Picker
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}{GLYPH_CHAT}{/snippet}
		chat
		{#snippet menu()}
			<!-- TODO @many maybe a copy submenu on this item with copy id, name, etc, leverage generic cells -->
			<Contextmenu_Copy_To_Clipboard content={chat.name} label="copy name" />
			<Contextmenu_Copy_To_Clipboard content={chat.id} label="copy id" />

			{#if chat.tapes.length}
				<Contextmenu_Entry run={() => chat.remove_all_tapes()}>
					{#snippet icon()}{GLYPH_REMOVE}{/snippet}
					<span>remove all tapes</span>
				</Contextmenu_Entry>
			{/if}

			{#if chat.selected_prompt_ids.length}
				<Contextmenu_Entry
					run={() => {
						chat.selected_prompt_ids = [];
					}}
				>
					{#snippet icon()}{GLYPH_PROMPT}{/snippet}
					<span>clear selected prompts</span>
				</Contextmenu_Entry>
			{/if}

			{#if chat.main_input}
				<Contextmenu_Copy_To_Clipboard
					content={chat.main_input}
					label="copy input"
					preview_limit={30}
				/>

				<Contextmenu_Entry
					run={() => {
						chat.main_input = '';
					}}
				>
					{#snippet icon()}{GLYPH_REMOVE}{/snippet}
					<span>clear input</span>
				</Contextmenu_Entry>
			{/if}

			<Contextmenu_Entry
				run={() => {
					// Open name edit dialog or other rename mechanism.
					// This is a placeholder for future implementation.
					const new_name = prompt('Enter new name for chat:', chat.name); // eslint-disable-line no-alert
					if (new_name && new_name !== chat.name) {
						chat.name = new_name;
					}
				}}
			>
				{#snippet icon()}{GLYPH_EDIT}{/snippet}
				<span>rename chat</span>
			</Contextmenu_Entry>

			<Contextmenu_Entry
				run={() => {
					// TODO clone/registry
					// Create a duplicate of this chat
					const new_chat = zzz.chats.add_chat(chat.clone());

					// Add the same tapes
					for (const tape of chat.tapes) {
						new_chat.add_tape(tape.model);
					}

					// Select the new chat
					zzz.chats.select(new_chat.id);
				}}
			>
				{#snippet icon()}{GLYPH_CHAT}{/snippet}
				<span>duplicate chat</span>
			</Contextmenu_Entry>

			<Contextmenu_Entry
				run={() => {
					// TODO @many better confirmation
					// eslint-disable-next-line no-alert
					if (confirm(`Are you sure you want to delete the chat "${chat.name}"?`)) {
						zzz.chats.remove(chat.id);
					}
				}}
			>
				{#snippet icon()}{GLYPH_DELETE}{/snippet}
				<span>delete chat</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}
