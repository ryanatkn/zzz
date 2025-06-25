<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Tape} from '$lib/tape.svelte.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import {GLYPH_DELETE, GLYPH_REMOVE, GLYPH_TAPE, GLYPH_MODEL} from '$lib/glyphs.js';
	import Contextmenu_Entry_Toggle from '$lib/Contextmenu_Entry_Toggle.svelte';
	import Contextmenu_Entry_Copy_To_Clipboard from '$lib/Contextmenu_Entry_Copy_To_Clipboard.svelte';
	import Model_Picker_Dialog from '$lib/Model_Picker_Dialog.svelte';
	import Glyph from '$lib/Glyph.svelte';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		tape: Tape;
	}

	const {tape, ...rest}: Props = $props();

	const app = frontend_context.get();

	let show_model_picker = $state(false);
</script>

<Contextmenu {...rest} {entries} />

<Model_Picker_Dialog
	bind:show={show_model_picker}
	onpick={(model) => {
		if (model) {
			tape.switch_model(model.id);
		}
	}}
/>

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}<Glyph glyph={GLYPH_TAPE} />{/snippet}
		tape
		{#snippet menu()}
			{#if tape.content}
				<Contextmenu_Entry_Copy_To_Clipboard
					content={tape.content}
					label="copy conversation"
					preview={tape.content_preview}
				/>
			{/if}

			{#if tape.strips.size > 0}
				<Contextmenu_Entry
					run={() => {
						tape.remove_all_strips();
					}}
				>
					{#snippet icon()}<Glyph glyph={GLYPH_REMOVE} />{/snippet}
					<span>clear conversation</span>
				</Contextmenu_Entry>
			{/if}

			<Contextmenu_Entry_Toggle bind:enabled={tape.enabled} label="tape" />

			<Contextmenu_Entry run={() => (show_model_picker = true)}>
				{#snippet icon()}<Glyph glyph={GLYPH_MODEL} />{/snippet}
				switch model &nbsp; <small>{tape.model_name}</small>
			</Contextmenu_Entry>

			<Contextmenu_Entry
				run={() => {
					// TODO @many better confirmation
					// eslint-disable-next-line no-alert
					if (confirm(`Are you sure you want to delete this tape?`)) {
						app.tapes.remove(tape.id);
					}
				}}
			>
				{#snippet icon()}<Glyph glyph={GLYPH_DELETE} />{/snippet}
				<span>delete tape</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}
