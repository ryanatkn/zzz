<script lang="ts">
	import {base} from '$app/paths';
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Provider} from '$lib/provider.svelte.js';
	import Model_Summary from '$lib/Model_Summary.svelte';
	import Provider_Logo from '$lib/Provider_Logo.svelte';
	import {GLYPH_PROVIDER} from '$lib/glyphs.js';
	import External_Link from '$lib/External_Link.svelte';

	interface Props {
		provider: Provider;
		attrs?: SvelteHTMLElements['div'] | undefined;
	}

	const {provider, attrs}: Props = $props();

	const at_detail_page = $derived(page.url.pathname === `${base}/providers/${provider.name}`);
</script>

<div {...attrs} class="panel p_lg {attrs?.class}">
	<div class="flex mb_lg">
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
			{#if provider.icon}
				<div>{provider.icon}</div>
			{/if}
			<div>
				<div class="mb_md font_mono">{GLYPH_PROVIDER} {provider.name}</div>
				<div>
					<External_Link href={provider.url}>docs</External_Link>
				</div>
			</div>
		</div>
	</div>
	<section>
		<ul class="flex flex_wrap unstyled gap_md">
			{#each provider.models as model (model)}
				<Model_Summary {model} />
			{/each}
		</ul>
	</section>
</div>
