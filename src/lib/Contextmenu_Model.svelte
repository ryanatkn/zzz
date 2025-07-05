<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import Contextmenu_Submenu from '@ryanatkn/fuz/Contextmenu_Submenu.svelte';
	import Contextmenu_Link_Entry from '@ryanatkn/fuz/Contextmenu_Link_Entry.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Model} from '$lib/model.svelte.js';
	import {
		GLYPH_MODEL,
		GLYPH_REFRESH,
		GLYPH_PROVIDER,
		GLYPH_CHECKMARK,
		GLYPH_CHAT,
	} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Contextmenu_Entry_Copy_To_Clipboard from '$lib/Contextmenu_Entry_Copy_To_Clipboard.svelte';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		model: Model;
	}

	const {model, ...rest}: Props = $props();
</script>

<Contextmenu {...rest} {entries} />

<!-- TODO maybe extract Contextmenu_Model_Entries that can be used elsewhere like the Model_Link as an action? -->
{#snippet entries()}
	<Contextmenu_Submenu>
		{#snippet icon()}<Glyph glyph={GLYPH_MODEL} />{/snippet}
		model

		{#snippet menu()}
			<Contextmenu_Link_Entry href="/models/{model.name}">
				{#snippet icon()}<Glyph glyph={GLYPH_MODEL} />{/snippet}
			</Contextmenu_Link_Entry>

			<Contextmenu_Entry_Copy_To_Clipboard content={model.name} label="copy name" />

			<Contextmenu_Entry run={() => model.app.chats.add(undefined, true).add_tape(model)}>
				{#snippet icon()}<Glyph glyph={GLYPH_CHAT} />{/snippet}
				<span>create new chat</span>
			</Contextmenu_Entry>

			{#if model.provider_name === 'ollama'}
				<Contextmenu_Entry
					run={async () => {
						await model.navigate_to_provider_model_view();
					}}
				>
					{#snippet icon()}<Glyph glyph={GLYPH_MODEL} />{/snippet}
					<span>manage Ollama model</span>
				</Contextmenu_Entry>
				<!-- TODO I think we want `disabled` to be supported on Contextmenu_Entry here for loading states -->
				<Contextmenu_Entry
					run={async () => {
						await model.app.api.ollama_show({model: model.name});
					}}
				>
					{#snippet icon()}<Glyph glyph={GLYPH_REFRESH} />{/snippet}
					<span
						>{#if model.ollama_show_response_loaded}re{/if}load Ollama details</span
					>
				</Contextmenu_Entry>
			{/if}

			<!-- TODO probably want an "edit model" form but this will do for now -->
			<Contextmenu_Submenu>
				{#snippet icon()}<Glyph glyph={GLYPH_PROVIDER} />{/snippet}
				set provider

				{#snippet menu()}
					{#each model.app.providers.names as provider_name (provider_name)}
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
