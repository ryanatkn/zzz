<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import ContextmenuEntry from '@ryanatkn/fuz/ContextmenuEntry.svelte';
	import ContextmenuSubmenu from '@ryanatkn/fuz/ContextmenuSubmenu.svelte';
	import type {OmitStrict} from '@ryanatkn/belt/types.js';

	import type {Thread} from '$lib/thread.svelte.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import {GLYPH_DELETE, GLYPH_REMOVE, GLYPH_THREAD, GLYPH_MODEL} from '$lib/glyphs.js';
	import ContextmenuEntryToggle from '$lib/ContextmenuEntryToggle.svelte';
	import ContextmenuEntryCopyToClipboard from '$lib/ContextmenuEntryCopyToClipboard.svelte';
	import ModelPickerDialog from '$lib/ModelPickerDialog.svelte';
	import Glyph from '$lib/Glyph.svelte';

	const {
		thread,
		...rest
	}: OmitStrict<ComponentProps<typeof Contextmenu>, 'entries'> & {
		thread: Thread;
	} = $props();

	const app = frontend_context.get();

	let show_model_picker = $state(false);
</script>

<Contextmenu {...rest} {entries} />

<ModelPickerDialog
	bind:show={show_model_picker}
	onpick={(model) => {
		if (model) {
			thread.switch_model(model.id);
		}
	}}
/>

{#snippet entries()}
	<ContextmenuSubmenu>
		{#snippet icon()}<Glyph glyph={GLYPH_THREAD} />{/snippet}
		thread
		{#snippet menu()}
			{#if thread.content}
				<ContextmenuEntryCopyToClipboard
					content={thread.content}
					label="copy conversation"
					preview={thread.content_preview}
				/>
			{/if}

			{#if thread.turns.size > 0}
				<ContextmenuEntry
					run={() => {
						thread.remove_all_turns();
					}}
				>
					{#snippet icon()}<Glyph glyph={GLYPH_REMOVE} />{/snippet}
					<span>clear conversation</span>
				</ContextmenuEntry>
			{/if}

			<ContextmenuEntryToggle bind:enabled={thread.enabled} label="thread" />

			<ContextmenuEntry run={() => (show_model_picker = true)}>
				{#snippet icon()}<Glyph glyph={GLYPH_MODEL} />{/snippet}
				switch model &nbsp; <small>{thread.model_name}</small>
			</ContextmenuEntry>

			<ContextmenuEntry
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
			</ContextmenuEntry>
		{/snippet}
	</ContextmenuSubmenu>
{/snippet}
