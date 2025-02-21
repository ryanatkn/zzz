<script lang="ts">
	import {providers_default} from '$lib/config.js';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {GLYPH_MODEL, GLYPH_PROVIDER} from '$lib/constants.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	const models = $derived(zzz.models);
</script>

<div class="p_lg">
	<h1><Text_Icon icon={GLYPH_PROVIDER} /> providers</h1>
	<div class="providers_grid">
		{#each providers_default as provider (provider)}
			<div class="panel p_lg">
				<div class="size_xl mb_lg">
					<Provider_Link {provider} attrs={{class: 'font_weight_500'}} />
				</div>
				<div class="mb_sm font_mono">{GLYPH_PROVIDER} {provider.name}</div>
				{#if provider.url}
					<div class="mb_sm">
						<a href={provider.url} target="_blank" rel="noreferrer"
							>docs <sup class="size_xs font_mono">[🡵]</sup></a
						>
					</div>
				{/if}
				{#if provider.icon}
					<div class="mb_sm">
						<img src={provider.icon} alt={`${provider.title} icon`} class="provider_icon" />
					</div>
				{/if}
				<!-- <h3><Text_Icon icon={GLYPH_MODEL} /> models</h3> -->
				<ul class="unstyled">
					{#each models.filter((m) => m.provider_name === provider.name) as model (model)}
						<li class="row flex_wrap mb_xs3">
							<Model_Link attrs={{class: 'font_mono px_xs size_sm font_weight_500'}} {model}
								>{GLYPH_MODEL} {model.name}</Model_Link
							>
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
		padding: var(--space_md);
	}

	.provider_icon {
		max-width: 32px;
		max-height: 32px;
		object-fit: contain;
	}
</style>
