<script lang="ts">
	import {format_url} from '@ryanatkn/belt/url.js';

	import Provider_Link from '$lib/Provider_Link.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_CHECKMARK, GLYPH_PROVIDER} from '$lib/glyphs.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import External_Link from '$lib/External_Link.svelte';
	import Provider_Logo from '$lib/Provider_Logo.svelte';

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
				<p>
					<Glyph glyph={GLYPH_PROVIDER} />{provider.name}
				</p>
				{#if provider.homepage}
					<p>
						<External_Link href={provider.homepage}>{format_url(provider.homepage)}</External_Link>
					</p>
				{/if}
				{#if provider.url}
					<p>
						<External_Link href={provider.url}>docs</External_Link>
					</p>
				{/if}
				<ul class="unstyled">
					{#each provider.models as model (model)}
						<li class="row">
							<Model_Link class="font_family_mono w_100 row px_xs py_xs3 font_size_md" {model}>
								<div class="flex_1">
									<Provider_Logo name={model.provider_name} />
									<span class="pl_sm">{model.name}</span>
								</div>
								{#if model.provider_name === 'ollama'}<Glyph
										glyph={model.downloaded ? GLYPH_CHECKMARK : ' '}
										title={model.downloaded ? 'downloaded' : 'not downloaded'}
									/>{/if}
							</Model_Link>
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
