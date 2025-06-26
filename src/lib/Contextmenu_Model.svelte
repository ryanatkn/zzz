<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import Contextmenu_Link_Entry from '@ryanatkn/fuz/Contextmenu_Link_Entry.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Model} from '$lib/model.svelte.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import {GLYPH_MODEL, GLYPH_REFRESH, GLYPH_PROVIDER, GLYPH_CHECKMARK} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Contextmenu_Entry_Copy_To_Clipboard from '$lib/Contextmenu_Entry_Copy_To_Clipboard.svelte';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		model: Model;
	}

	const {model, ...rest}: Props = $props();

	const app = frontend_context.get();
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}<Glyph glyph={GLYPH_MODEL} />{/snippet}
		model

		{#snippet menu()}
			<Contextmenu_Link_Entry href="/models/{model.name}">
				{#snippet icon()}<Glyph glyph={GLYPH_MODEL} />{/snippet}
			</Contextmenu_Link_Entry>

			<Contextmenu_Entry_Copy_To_Clipboard content={model.name} label="copy name" />

			{#if model.ollama_list_response_item?.digest}
				<Contextmenu_Entry_Copy_To_Clipboard
					content={model.ollama_list_response_item.digest}
					label="copy digest"
					preview={model.ollama_list_response_item.digest.slice(0, 12) + '...'}
				/>
			{/if}

			{#if model.provider_name === 'ollama' && model.needs_ollama_details}
				<Contextmenu_Entry
					run={async () => {
						await app.ollama.show_model(model.name);
					}}
				>
					{#snippet icon()}<Glyph glyph={GLYPH_REFRESH} />{/snippet}
					<span>load ollama details</span>
				</Contextmenu_Entry>
			{/if}

			{#if model.provider_name === 'ollama' && model.ollama_show_response_loaded}
				<Contextmenu_Entry
					run={async () => {
						await app.ollama.refresh_model_details(model.name);
					}}
				>
					{#snippet icon()}<Glyph glyph={GLYPH_REFRESH} />{/snippet}
					<span>refresh ollama details</span>
				</Contextmenu_Entry>
			{/if}

			<!-- TODO probably want an "edit model" form but this will do for now -->
			<Contextmenu_Submenu>
				{#snippet icon()}<Glyph glyph={GLYPH_PROVIDER} />{/snippet}
				set provider

				{#snippet menu()}
					{#each app.providers.names as provider_name (provider_name)}
						<Contextmenu_Entry
							run={() => {
								model.provider_name = provider_name;
							}}
						>
							{#snippet icon()}
								{#if model.provider_name === provider_name}<Glyph glyph={GLYPH_CHECKMARK} />{/if}
							{/snippet}
							<span>{provider_name}</span>
						</Contextmenu_Entry>
					{/each}
				{/snippet}
			</Contextmenu_Submenu>
		{/snippet}
	</Contextmenu_Submenu>
{/snippet}
