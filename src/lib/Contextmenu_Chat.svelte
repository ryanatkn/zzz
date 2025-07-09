<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Chat} from '$lib/chat.svelte.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import {
		GLYPH_CHAT,
		GLYPH_DELETE,
		GLYPH_EDIT,
		GLYPH_REMOVE,
		GLYPH_VIEW,
		GLYPH_ADD,
	} from '$lib/glyphs.js';
	import Contextmenu_Entry_Copy_To_Clipboard from '$lib/Contextmenu_Entry_Copy_To_Clipboard.svelte';
	import Model_Picker_Dialog from '$lib/Model_Picker_Dialog.svelte';
	import Glyph from '$lib/Glyph.svelte';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		chat: Chat;
	}

	const {chat, ...rest}: Props = $props();

	const app = frontend_context.get();

	let show_model_picker = $state(false);

	// TODO BLOCK edit chat dialog instead of prompt for name (just focus the input for now?)
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}<Glyph glyph={GLYPH_CHAT} />{/snippet}
		chat
		{#snippet menu()}
			<Contextmenu_Entry run={() => (show_model_picker = true)}>
				{#snippet icon()}<Glyph glyph={GLYPH_ADD} />{/snippet}
				<span>add tape</span>
			</Contextmenu_Entry>

			<Contextmenu_Entry
				run={() => {
					chat.view_mode = chat.view_mode === 'simple' ? 'multi' : 'simple';
				}}
			>
				{#snippet icon()}<Glyph glyph={GLYPH_VIEW} />{/snippet}
				<span>{chat.view_mode === 'simple' ? 'multi' : 'simple'} view</span>
			</Contextmenu_Entry>

			<!-- TODO @many maybe a copy submenu on this item with copy id, name, etc, leverage generic cells -->
			<Contextmenu_Entry_Copy_To_Clipboard content={chat.id} label="copy id" />

			{#if chat.tapes.length}
				<Contextmenu_Entry run={() => chat.remove_all_tapes()}>
					{#snippet icon()}<Glyph glyph={GLYPH_REMOVE} />{/snippet}
					<span>remove all tapes</span>
				</Contextmenu_Entry>
			{/if}

			{#if chat.main_input}
				<Contextmenu_Entry_Copy_To_Clipboard
					content={chat.main_input}
					label="copy input"
					preview_limit={30}
				/>

				<Contextmenu_Entry
					run={() => {
						chat.main_input = '';
					}}
				>
					{#snippet icon()}<Glyph glyph={GLYPH_REMOVE} />{/snippet}
					<span>clear input</span>
				</Contextmenu_Entry>
			{/if}

			<Contextmenu_Entry
				run={() => {
					// TODO make this focus the `Editable_Text` if available, somehow
					const new_name = prompt('Enter new name for chat:', chat.name); // eslint-disable-line no-alert
					if (new_name && new_name !== chat.name) {
						chat.name = new_name;
					}
				}}
			>
				{#snippet icon()}<Glyph glyph={GLYPH_EDIT} />{/snippet}
				<span>rename chat</span>
			</Contextmenu_Entry>

			<Contextmenu_Entry
				run={async () => {
					// TODO BLOCK this is broken bc we want a unique name, and adding tapes looks hacky, maybe add a `chats/chat.duplicate` method
					// Create a duplicate of this chat
					const new_chat = app.chats.add_chat(chat.clone());

					// Add the same tapes
					for (const tape of chat.tapes) {
						new_chat.add_tape(tape.model);
					}

					// Select the new chat
					await app.chats.navigate_to(new_chat.id);
				}}
			>
				{#snippet icon()}<Glyph glyph={GLYPH_CHAT} />{/snippet}
				<span>duplicate chat</span>
			</Contextmenu_Entry>

			<Contextmenu_Entry
				run={() => {
					// TODO @many better confirmation
					// eslint-disable-next-line no-alert
					if (confirm(`Are you sure you want to delete the chat "${chat.name}"?`)) {
						app.chats.remove(chat.id);
					}
				}}
			>
				{#snippet icon()}<Glyph glyph={GLYPH_DELETE} />{/snippet}
				<span>delete chat</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}

<Model_Picker_Dialog
	bind:show={show_model_picker}
	onpick={(model) => {
		if (model) {
			chat.add_tape(model); // TODO @many insert at an index via a range input
		}
	}}
/>
