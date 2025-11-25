<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import ContextmenuEntry from '@ryanatkn/fuz/ContextmenuEntry.svelte';
	import ContextmenuSubmenu from '@ryanatkn/fuz/ContextmenuSubmenu.svelte';
	import ContextmenuLinkEntry from '@ryanatkn/fuz/ContextmenuLinkEntry.svelte';
	import type {OmitStrict} from '@ryanatkn/belt/types.js';

	import type {Model} from '$lib/model.svelte.js';
	import {GLYPH_MODEL, GLYPH_CHAT} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import ContextmenuEntryCopyToClipboard from '$lib/ContextmenuEntryCopyToClipboard.svelte';

	const {
		model,
		...rest
	}: OmitStrict<ComponentProps<typeof Contextmenu>, 'entries'> & {
		model: Model;
	} = $props();
</script>

<Contextmenu {...rest} {entries} />

<!-- TODO maybe extract ModelContextmenuEntries that can be used elsewhere like the ModelLink as an action? -->
{#snippet entries()}
	<ContextmenuSubmenu>
		{#snippet icon()}<Glyph glyph={GLYPH_MODEL} />{/snippet}
		model

		{#snippet menu()}
			<ContextmenuLinkEntry href="/models/{model.name}">
				{#snippet icon()}<Glyph glyph={GLYPH_MODEL} />{/snippet}
			</ContextmenuLinkEntry>

			<ContextmenuEntryCopyToClipboard content={model.name} label="copy name" />

			<ContextmenuEntry run={() => model.app.chats.add(undefined, true).add_thread(model)}>
				{#snippet icon()}<Glyph glyph={GLYPH_CHAT} />{/snippet}
				<span>create new chat</span>
			</ContextmenuEntry>

			{#if model.provider_name === 'ollama'}
				<ContextmenuEntry
					run={async () => {
						await model.navigate_to_provider_model_view();
					}}
				>
					{#snippet icon()}<Glyph glyph={GLYPH_MODEL} />{/snippet}
					<span>manage Ollama model</span>
				</ContextmenuEntry>
			{/if}

			<!-- TODO probably want an "edit model" form, this is confusing as-is -->
			<!-- <ContextmenuSubmenu>
				{#snippet icon()}<Glyph glyph={GLYPH_PROVIDER} />{/snippet}
				set provider

				{#snippet menu()}
					{#each model.app.providers.names as provider_name (provider_name)}
						<ContextmenuEntry
							run={() => {
								model.provider_name = provider_name;
							}}
						>
							{#snippet icon()}
								{#if model.provider_name === provider_name}<Glyph glyph={GLYPH_CHECKMARK} />{/if}
							{/snippet}
							<span>{provider_name}</span>
						</ContextmenuEntry>
					{/each}
				{/snippet}
			</ContextmenuSubmenu> -->
		{/snippet}
	</ContextmenuSubmenu>
{/snippet}
