<script lang="ts">
	import type {Snippet} from 'svelte';
	import {base} from '$app/paths';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {page} from '$app/state';
	import {DEV} from 'esm-env';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {chatgpt_logo, claude_logo, gemini_logo, ollama_logo} from '@ryanatkn/fuz/logos.js';

	import type {Provider_Json} from '$lib/provider.svelte.js';
	import {GLYPH_PROVIDER} from '$lib/constants.js';

	interface Props {
		provider: Provider_Json; // TODO BLOCK Provider, not Provider_Json?
		icon?: 'glyph' | 'svg' | Snippet<[svg_icon: Snippet, glyph: string]>;
		svg_fill?: string;
		svg_size?: string;
		svg_inline?: boolean;
		row?: boolean;
		show_name?: boolean;
		attrs?: SvelteHTMLElements['a'];
		children?: Snippet;
	}

	const {
		provider,
		icon,
		svg_fill = 'var(--text_color)',
		svg_size = 'var(--size_xl)',
		svg_inline = true,
		show_name,
		attrs,
		children,
	}: Props = $props();

	if (DEV && icon && children) console.error('icon and children are mutually exclusive');

	const selected = $derived(page.url.pathname === `${base}/providers/${provider.name}`);

	const provider_logos = {
		chatgpt: chatgpt_logo,
		claude: claude_logo,
		gemini: gemini_logo,
		ollama: ollama_logo,
	};
</script>

<a {...attrs} href="{base}/providers/{provider.name}" class:selected
	>{#if children}
		{@render children()}
	{:else}
		{#if icon === 'glyph'}
			{GLYPH_PROVIDER}
		{:else if icon === 'svg'}
			{@render svg_icon()}
		{:else if icon}
			{@render icon(svg_icon, GLYPH_PROVIDER)}
		{/if}
		{#if show_name}
			{provider.name}
		{:else}
			{provider.title}
		{/if}
	{/if}</a
>

{#snippet svg_icon(fill = svg_fill, size = svg_size, inline = svg_inline)}
	<Svg data={provider_logos[provider.name]} {fill} {size} {inline} />
{/snippet}

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
