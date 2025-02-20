<script lang="ts">
	import {providers_default, models_default} from '$lib/config.js';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {SYMBOL_PROVIDER} from '$lib/constants.js';

	// TODO BLOCK link the models below to a page per model (lookup from model_default/context)
</script>

<div class="p_lg">
	<h1><Text_Icon icon={SYMBOL_PROVIDER} /> providers</h1>
	<div class="providers_grid">
		{#each providers_default as provider (provider)}
			<div class="panel p_lg">
				<h2 class="mt_0 mb_lg">
					<Provider_Link {provider} />
				</h2>
				<div class="mb_sm font_mono">{provider.name}</div>
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
				<ul class="unstyled">
					{#each models_default.filter((m) => m.provider_name === provider.name) as model (model)}
						<li class="row">
							<Model_Link attrs={{class: 'chip'}} {model} />
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
