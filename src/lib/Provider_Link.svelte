<script lang="ts">
	import type {Snippet} from 'svelte';
	import {base} from '$app/paths';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {page} from '$app/state';

	import type {Provider_Json} from '$lib/provider.svelte.js';
	import {GLYPH_PROVIDER} from './constants.js';

	interface Props {
		provider: Provider_Json; // TODO BLOCK Provider, not Provider_Json?
		icon?: boolean;
		show_name?: boolean;
		attrs?: SvelteHTMLElements['a'];
		children?: Snippet;
	}

	const {provider, icon, show_name, attrs, children}: Props = $props();

	const selected = $derived(page.url.pathname === `${base}/providers/${provider.name}`);
</script>

<a {...attrs} href="{base}/providers/{provider.name}" class:selected
	>{#if children}
		{@render children()}
	{:else}
		{#if icon}
			{GLYPH_PROVIDER}
		{/if}
		{#if show_name}{provider.name}{:else}{provider.title}{/if}
	{/if}</a
>

<style>
	a {
		font-weight: 500;
	}
	/* TODO breaks convention, but I think it looks better in a lot of cases, maybe extract a class? `plain_selected_link` or `plain`? */
	.selected {
		font-weight: 400;
		text-decoration: none;
	}
</style>
