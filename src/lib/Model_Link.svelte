<script lang="ts">
	import type {Snippet} from 'svelte';
	import {page} from '$app/state';
	import {resolve} from '$app/paths';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Model} from '$lib/model.svelte.js';
	import Provider_Logo from '$lib/Provider_Logo.svelte';
	import {GLYPH_MODEL} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Model_Contextmenu from '$lib/Model_Contextmenu.svelte';

	const {
		model,
		icon,
		name,
		children,
		...rest
	}: SvelteHTMLElements['a'] & {
		model: Model;
		/**
		 * `true` is equivalent to `'svg'`
		 */
		icon?: boolean | 'svg' | 'glyph' | undefined;
		name?: Snippet | undefined;
	} = $props();

	const selected = $derived(page.url.pathname === resolve(`/models/${model.name}`));
</script>

<!-- TODO this contextmenu appears as a duplicate, I think a de-duped key is the best fix, not manually disabling it -->
<Model_Contextmenu {model}
	><a {...rest} href={resolve(`/models/${model.name}`)} class:selected
		>{#if children}
			{@render children()}
		{:else}
			{#if icon === 'svg' || icon === true}
				<Provider_Logo name={model.provider_name} />
			{:else if icon === 'glyph'}
				<Glyph glyph={GLYPH_MODEL} />
			{/if}
			{#if name}{@render name()}{:else}{model.name}{/if}
		{/if}</a
	></Model_Contextmenu
>

<style>
	a {
		font-weight: 600;
	}
	/* TODO breaks convention, but I think it looks better in a lot of cases, maybe extract a class? `plain_selected_link` or `plain`? */
	.selected {
		font-weight: 400;
		text-decoration: none;
	}
</style>
