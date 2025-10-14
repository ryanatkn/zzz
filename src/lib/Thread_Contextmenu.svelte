<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Thread} from '$lib/thread.svelte.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import {GLYPH_DELETE, GLYPH_REMOVE, GLYPH_THREAD, GLYPH_MODEL} from '$lib/glyphs.js';
	import Contextmenu_Entry_Toggle from '$lib/Contextmenu_Entry_Toggle.svelte';
	import Contextmenu_Entry_Copy_To_Clipboard from '$lib/Contextmenu_Entry_Copy_To_Clipboard.svelte';
	import Model_Picker_Dialog from '$lib/Model_Picker_Dialog.svelte';
	import Glyph from '$lib/Glyph.svelte';

	const {
		thread,
		...rest
	}: Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> & {
		thread: Thread;
	} = $props();

	const app = frontend_context.get();

	let show_model_picker = $state(false);
</script>

<Contextmenu {...rest} {entries} />

<Model_Picker_Dialog
	bind:show={show_model_picker}
	onpick={(model) => {
		if (model) {
			thread.switch_model(model.id);
		}
	}}
/>

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}<Glyph glyph={GLYPH_THREAD} />{/snippet}
		thread
		{#snippet menu()}
			{#if thread.content}
				<Contextmenu_Entry_Copy_To_Clipboard
					content={thread.content}
					label="copy conversation"
					preview={thread.content_preview}
				/>
			{/if}

			{#if thread.turns.size > 0}
				<Contextmenu_Entry
					run={() => {
						thread.remove_all_turns();
					}}
				>
					{#snippet icon()}<Glyph glyph={GLYPH_REMOVE} />{/snippet}
					<span>clear conversation</span>
				</Contextmenu_Entry>
			{/if}

			<Contextmenu_Entry_Toggle bind:enabled={thread.enabled} label="thread" />

			<Contextmenu_Entry run={() => (show_model_picker = true)}>
				{#snippet icon()}<Glyph glyph={GLYPH_MODEL} />{/snippet}
				switch model &nbsp; <small>{thread.model_name}</small>
			</Contextmenu_Entry>

			<Contextmenu_Entry
				run={() => {
					// TODO @many better confirmation
					// eslint-disable-next-line no-alert
					if (confirm(`Are you sure you want to delete this thread?`)) {
						app.threads.remove(thread.id);
					}
				}}
			>
				{#snippet icon()}<Glyph glyph={GLYPH_DELETE} />{/snippet}
				<span>delete thread</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}
