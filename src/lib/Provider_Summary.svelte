<script lang="ts">
	import {resolve} from '$app/paths';
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Provider} from '$lib/provider.svelte.js';
	import Model_Summary from '$lib/Model_Summary.svelte';
	import External_Link from '$lib/External_Link.svelte';

	const {
		provider,
		attrs,
	}: {
		provider: Provider;
		attrs?: SvelteHTMLElements['div'] | undefined;
	} = $props();

	const at_detail_page = $derived(page.url.pathname === resolve(`/providers/${provider.name}`));
</script>

<div {...attrs} class="panel p_lg {attrs?.class}">
	{#if at_detail_page}
		<h1>
			{provider.title}
		</h1>
	{:else}
		<h2>
			<External_Link href={provider.url}>{provider.title}</External_Link>
		</h2>
	{/if}
	<section>
		<div class="mb_md font_family_mono">{provider.name}</div>
		<div>
			<External_Link href={provider.url}>docs</External_Link>
		</div>
	</section>
	<ul class="display_flex flex_wrap_wrap unstyled gap_md">
		{#each provider.models as model (model)}
			<Model_Summary {model} />
		{/each}
	</ul>
</div>
