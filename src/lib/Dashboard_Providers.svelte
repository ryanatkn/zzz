<script lang="ts">
	import Provider_Link from '$lib/Provider_Link.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_PROVIDER} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import External_Link from '$lib/External_Link.svelte';

	const zzz = zzz_context.get();
</script>

<div class="p_lg">
	<h1><Glyph text={GLYPH_PROVIDER} /> providers</h1>
	<aside>⚠️ This information is incomplete and may be incorrect or outdated.</aside>
	<div class="providers_grid">
		{#each zzz.providers.items as provider (provider)}
			<div class="panel p_lg">
				<div class="size_xl mb_lg">
					<Provider_Link {provider} icon="svg" />
				</div>
				<div class="mb_sm font_mono">
					<span class="glyph">{GLYPH_PROVIDER}</span>
					{provider.name}
				</div>
				{#if provider.url}
					<div class="mb_sm">
						<External_Link href={provider.url}>docs</External_Link>
					</div>
				{/if}
				{#if provider.icon}
					<div class="mb_sm">
						<img src={provider.icon} alt={`${provider.title} icon`} class="provider_icon" />
					</div>
				{/if}
				<ul class="unstyled">
					{#each provider.models as model (model)}
						<li class="row flex_wrap mb_xs3">
							<Model_Link attrs={{class: 'font_mono px_xs size_sm'}} {model} icon />
							<!-- {#each model.tags as tag (tag)}
								<small class="chip">{tag}</small>
							{/each} -->
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

	.provider_icon {
		max-width: 32px;
		max-height: 32px;
		object-fit: contain;
	}
</style>
