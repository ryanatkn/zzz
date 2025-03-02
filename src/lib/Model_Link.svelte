<script lang="ts">
	import type {Snippet} from 'svelte';
	import {page} from '$app/state';
	import {base} from '$app/paths';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Model} from '$lib/model.svelte.js';
	import Provider_Logo from '$lib/Provider_Logo.svelte';
	import {GLYPH_MODEL} from '$lib/glyphs.js';

	interface Props {
		model: Model;
		/**
		 * `true` is equivalent to `'svg'`
		 */
		icon?: boolean | 'svg' | 'glyph';
		attrs?: SvelteHTMLElements['a'];
		children?: Snippet;
	}

	const {model, icon, attrs, children}: Props = $props();

	const selected = $derived(page.url.pathname === `${base}/models/${model.name}`);
</script>

<a {...attrs} href="{base}/models/{model.name}" class:selected
	>{#if children}
		{@render children()}
	{:else}
		{#if icon === 'svg' || icon === true}
			<Provider_Logo name={model.provider_name} />
		{:else if icon === 'glyph'}
			<span class="glyph">{GLYPH_MODEL}</span>
		{/if}
		{model.name}
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
