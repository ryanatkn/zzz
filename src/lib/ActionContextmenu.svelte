<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import ContextmenuEntry from '@ryanatkn/fuz/ContextmenuEntry.svelte';
	import ContextmenuSubmenu from '@ryanatkn/fuz/ContextmenuSubmenu.svelte';
	import type {OmitStrict} from '@ryanatkn/belt/types.js';

	import type {Action} from './action.svelte.js';
	import {frontend_context} from './frontend.svelte.js';
	import {GLYPH_LOG, GLYPH_DELETE} from './glyphs.js';
	import ContextmenuEntryCopyToClipboard from './ContextmenuEntryCopyToClipboard.svelte';
	import Glyph from './Glyph.svelte';

	const {
		action,
		...rest
	}: OmitStrict<ComponentProps<typeof Contextmenu>, 'entries'> & {
		action: Action;
	} = $props();

	const app = frontend_context.get();
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<ContextmenuSubmenu>
		{#snippet icon()}<Glyph glyph={GLYPH_LOG} />{/snippet}
		action
		{#snippet menu()}
			<ContextmenuEntryCopyToClipboard content={action.method} label="copy method" />

			<ContextmenuEntryCopyToClipboard content={action.id} label="copy id" />

			<ContextmenuEntryCopyToClipboard
				content={() => action.json_serialized}
				label="copy json data"
				show_preview={false}
			/>

			<!-- TODO implement `action.retry` or `actions.retry` or something -- see `app.api` too
			{#if action.has_error}
				<ContextmenuEntry
					run={() => {
						console.log('Retry action:', action.method);
					}}
				>
					{#snippet icon()}<Glyph glyph={GLYPH_RETRY} />{/snippet}
					<span>retry action</span>
				</ContextmenuEntry>
			{/if} -->

			<ContextmenuEntry
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
			</ContextmenuEntry>
		{/snippet}
	</ContextmenuSubmenu>
{/snippet}
