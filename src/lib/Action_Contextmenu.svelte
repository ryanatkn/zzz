<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Action} from '$lib/action.svelte.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import {GLYPH_LOG, GLYPH_DELETE} from '$lib/glyphs.js';
	import Contextmenu_Entry_Copy_To_Clipboard from '$lib/Contextmenu_Entry_Copy_To_Clipboard.svelte';
	import Glyph from '$lib/Glyph.svelte';

	const {
		action,
		...rest
	}: Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> & {
		action: Action;
	} = $props();

	const app = frontend_context.get();
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}<Glyph glyph={GLYPH_LOG} />{/snippet}
		action
		{#snippet menu()}
			<Contextmenu_Entry_Copy_To_Clipboard content={action.method} label="copy method" />

			<Contextmenu_Entry_Copy_To_Clipboard content={action.id} label="copy id" />

			<Contextmenu_Entry_Copy_To_Clipboard
				content={() => action.json_serialized}
				label="copy json data"
				show_preview={false}
			/>

			<!-- TODO implement `action.retry` or `actions.retry` or something -- see `app.api` too
			{#if action.has_error}
				<Contextmenu_Entry
					run={() => {
						console.log('Retry action:', action.method);
					}}
				>
					{#snippet icon()}<Glyph glyph={GLYPH_RETRY} />{/snippet}
					<span>retry action</span>
				</Contextmenu_Entry>
			{/if} -->

			<Contextmenu_Entry
				run={() => {
					// TODO
					// eslint-disable-next-line no-alert
					if (confirm('delete this action from history? that sounds destructive')) {
						app.actions.items.remove(action.id);
					}
				}}
			>
				{#snippet icon()}<Glyph glyph={GLYPH_DELETE} />{/snippet}
				<span>delete from history</span>
			</Contextmenu_Entry>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}
