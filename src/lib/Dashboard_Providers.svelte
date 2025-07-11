<script lang="ts">
	import Provider_Link from '$lib/Provider_Link.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_CHECKMARK, GLYPH_PROVIDER} from '$lib/glyphs.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import External_Link from '$lib/External_Link.svelte';

	const app = frontend_context.get();
</script>

<div class="p_lg">
	<h1><Glyph glyph={GLYPH_PROVIDER} /> providers</h1>
	<aside>⚠️ This is a work in progress.</aside>
	<div class="providers_grid">
		{#each app.providers.items as provider (provider)}
			<div class="panel p_lg">
				<div class="font_size_xl mb_lg">
					<Provider_Link {provider} icon="svg" />
				</div>
				<div class="mb_lg">
					<Glyph glyph={GLYPH_PROVIDER} />{provider.name}
				</div>
				{#if provider.url}
					<div class="mb_lg">
						<External_Link href={provider.url}>docs</External_Link>
					</div>
				{/if}
				<ul class="unstyled">
					{#each provider.models as model (model)}
						<li class="row flex_wrap mb_xs3">
							{#if model.provider_name === 'ollama'}<Glyph
									glyph={model.downloaded ? GLYPH_CHECKMARK : ' '}
									attrs={{title: model.downloaded ? 'downloaded' : 'not downloaded'}}
								/>{/if}<Model_Link
								attrs={{class: 'font_family_mono px_xs font_size_sm'}}
								{model}
								icon
							/>
						</li>
					{/each}
				</ul>
			</div>
		{/each}
	</div>
</div>

<style>
	.providers_grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space_lg);
		width: 100%;
	}
</style>
