<script lang="ts">
	import {resolve} from '$app/paths';
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {format_url} from '@ryanatkn/belt/url.js';

	import type {Provider} from '$lib/provider.svelte.js';
	import Provider_Logo from '$lib/Provider_Logo.svelte';
	import {GLYPH_PROVIDER} from '$lib/glyphs.js';
	import External_Link from '$lib/External_Link.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import Ollama_Manager from '$lib/Ollama_Manager.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import Model_Summary from '$lib/Model_Summary.svelte';
	import Capability_Provider_Api from '$lib/Capability_Provider_Api.svelte';

	const {
		provider,
		attrs,
	}: {
		provider: Provider;
		attrs?: SvelteHTMLElements['div'] | undefined;
	} = $props();

	const at_detail_page = $derived(page.url.pathname === resolve(`/providers/${provider.name}`));

	const app = frontend_context.get();

	// TODO @many get and display Ollama version, JS API client doesnt have it but the REST API does
	// maybe at `<Glyph glyph={GLYPH_PROVIDER} />{provider.name}`
</script>

<div {...attrs} class="panel p_lg {attrs?.class}">
	<section class="display_flex mb_lg">
		<div class="display_flex">
			<Provider_Logo name={provider.name} size="var(--icon_size_xl)" fill={null} />
			<div class="pl_xl">
				{#if at_detail_page}
					<h1 class="mb_md">
						{provider.title}
					</h1>
				{:else}
					<h2 class="mb_md">
						<External_Link href={provider.url}>{provider.title}</External_Link>
					</h2>
				{/if}
				<p class="mb_md">{provider.company}</p>
				<p class="mb_md">
					<Glyph glyph={GLYPH_PROVIDER} />{provider.name}
				</p>
				<div class="row gap_xl">
					<External_Link href={provider.homepage}>{format_url(provider.homepage)}</External_Link>
					<External_Link href={provider.url}>docs</External_Link>
				</div>
			</div>
		</div>
	</section>

	<section>
		{#if provider.name === 'ollama'}
			<Ollama_Manager ollama={app.ollama} />
		{:else}
			<div class="width_upto_md mb_lg">
				<Capability_Provider_Api provider_name={provider.name} show_info={false} />
				{#if provider.api_key_url}
					<External_Link href={provider.api_key_url}>get API key</External_Link>
				{/if}
			</div>
		{/if}
	</section>

	<section>
		<aside>⚠️ This information is incomplete and may be incorrect or outdated.</aside>
		<ul class="display_flex flex_wrap_wrap unstyled gap_md">
			{#each provider.models as model (model)}
				<Model_Summary {model} omit_provider />
			{/each}
		</ul>
		<!-- TODO UI to add models -->
	</section>
</div>
