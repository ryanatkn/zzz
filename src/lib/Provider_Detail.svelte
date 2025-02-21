<script lang="ts">
	import {base} from '$app/paths';
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Provider_Json} from '$lib/provider.svelte.js';
	import Model_Summary from '$lib/Model_Summary.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_PROVIDER} from '$lib/constants.js';

	const zzz = zzz_context.get();

	interface Props {
		provider: Provider_Json;
		attrs?: SvelteHTMLElements['div'];
	}

	const {provider, attrs}: Props = $props();

	const on_detail_page = $derived(page.url.pathname === `${base}/providers/${provider.name}`);

	// TODO BLOCK use `provider.models`
	const models = $derived(zzz.models.filter((m) => m.provider_name === provider.name));
</script>

<div {...attrs} class="panel p_lg {attrs?.class}">
	{#if on_detail_page}
		<h1>
			{provider.title}
		</h1>
	{:else}
		<h2>
			<a href={provider.url} target="_blank" rel="noreferrer">{provider.title}</a>
		</h2>
	{/if}
	{#if provider.icon}
		<div>{provider.icon}</div>
	{/if}
	<section>
		<div class="mb_md font_mono">{GLYPH_PROVIDER} {provider.name}</div>
		<div>
			<a href={provider.url} target="_blank" rel="noreferrer"
				>docs <sup class="size_xs font_mono">[🡵]</sup></a
			>
		</div>
	</section>
	<section>
		<h2>models</h2>
		<ul class="flex flex_wrap unstyled gap_md">
			{#each models as model (model)}
				<Model_Summary {model} />
			{/each}
		</ul>
	</section>
</div>
