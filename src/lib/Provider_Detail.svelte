<script lang="ts">
	import {base} from '$app/paths';
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Provider} from '$lib/provider.svelte.js';
	import Provider_Logo from '$lib/Provider_Logo.svelte';
	import {GLYPH_PROVIDER} from '$lib/glyphs.js';
	import External_Link from '$lib/External_Link.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import Ollama_Manager from '$lib/Ollama_Manager.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import Model_Summary from '$lib/Model_Summary.svelte';

	interface Props {
		provider: Provider;
		attrs?: SvelteHTMLElements['div'] | undefined;
	}

	const {provider, attrs}: Props = $props();

	const at_detail_page = $derived(page.url.pathname === `${base}/providers/${provider.name}`);

	const app = frontend_context.get();
</script>

<div {...attrs} class="panel p_lg {attrs?.class}">
	<section class="display_flex mb_lg">
		<Provider_Logo name={provider.name} size="var(--icon_size_xl)" fill={null} />
		<div class="pl_xl">
			{#if at_detail_page}
				<h1 class="mb_md">
					{provider.title}
				</h1>
			{:else}
				<h2>
					<External_Link href={provider.url}>{provider.title}</External_Link>
				</h2>
			{/if}
			<div>
				<div class="mb_md font_family_mono">
					<Glyph glyph={GLYPH_PROVIDER} />
					{provider.name}
				</div>
				<div>
					<External_Link href={provider.url}>docs</External_Link>
				</div>
			</div>
		</div>
	</section>
	{#if provider.name === 'ollama'}
		<section>
			<Ollama_Manager ollama={app.ollama} />
		</section>
	{:else}
		<aside class="mt_xl3">
			⚠️ This information is incomplete and may be incorrect or outdated.
		</aside>
		<section>
			<ul class="display_flex flex_wrap unstyled gap_md">
				{#each provider.models as model (model)}
					<Model_Summary {model} />
				{/each}
			</ul>
			<!-- TODO UI to add models -->
		</section>
	{/if}
</div>
