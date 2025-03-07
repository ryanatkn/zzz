<script lang="ts">
	import type {Snippet} from 'svelte';
	import {base} from '$app/paths';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {page} from '$app/state';

	import type {Provider_Json} from '$lib/provider.svelte.js';
	import {GLYPH_PROVIDER} from '$lib/glyphs.js';
	import Provider_Logo from '$lib/Provider_Logo.svelte';

	interface Props {
		provider: Provider_Json | null | undefined; // TODO BLOCK Provider, not Provider_Json?
		icon?: 'glyph' | 'svg' | Snippet<[provider: Provider_Json, glyph: string]>;
		icon_props?: Record<string, any>;
		row?: boolean;
		show_name?: boolean;
		attrs?: SvelteHTMLElements['a'];
		fallback_attrs?: SvelteHTMLElements['span'];
		fallback?: Snippet;
		children?: Snippet;
	}

	const {provider, icon, icon_props, show_name, attrs, fallback_attrs, fallback, children}: Props =
		$props();

	if (icon && children) {
		console.error('icon and children are mutually exclusive');
	}
	if (fallback && fallback_attrs) {
		console.error('fallback and fallback_attrs are mutually exclusive');
	}

	const selected = $derived(
		!!provider && page.url.pathname === `${base}/providers/${provider.name}`,
	);
</script>

{#if provider}
	<a {...attrs} href="{base}/providers/{provider.name}" class:selected
		>{#if children}
			{@render children()}
		{:else}
			{#if icon === 'glyph'}
				<span class="glyph">{GLYPH_PROVIDER}</span>
			{:else if icon === 'svg'}
				<Provider_Logo name={provider.name} {...icon_props} />
			{:else if icon}
				{@render icon(provider, GLYPH_PROVIDER)}
			{/if}
			{#if show_name}
				{provider.name}
			{:else}
				{provider.title}
			{/if}
		{/if}</a
	>
{:else if fallback}
	{@render fallback()}
{:else}
	<small {...fallback_attrs} class="font_mono color_c_5 {fallback_attrs?.class}"
		>{GLYPH_PROVIDER} missing provider</small
	>
{/if}

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
