<script lang="ts">
	import type {Snippet} from 'svelte';
	import {page} from '$app/state';
	import {base} from '$app/paths';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Model} from '$lib/model.svelte.js';

	interface Props {
		model: Model;
		attrs?: SvelteHTMLElements['a'];
		children?: Snippet;
	}

	const {model, attrs, children}: Props = $props();

	const selected = $derived(page.url.pathname === `${base}/models/${model.name}`);
</script>

<a {...attrs} href="{base}/models/{model.name}" class:selected
	>{#if children}{@render children()}{:else}{model.name}{/if}</a
>

<style>
	/* TODO breaks convention, but I think it looks better in a lot of cases, maybe extract a class? `plain_selected_link` or `plain`? */
	.selected {
		font-weight: 400;
		text-decoration: none;
	}
</style>
