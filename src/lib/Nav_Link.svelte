<script lang="ts">
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Snippet} from 'svelte';

	interface Props {
		href: string;
		attrs?: SvelteHTMLElements['a'];
		children: Snippet;
	}

	const {href, attrs, children}: Props = $props();

	const selected = $derived(page.url.pathname === href);

	// TODO link styles should have focus always be blue, and active should be thicker
</script>

<a {...attrs} {href} class:selected>{@render children()}</a>

<style>
	a {
		display: flex;
		padding: var(--space_xs2) var(--space_md);
		text-decoration: none;
		border: var(--border_width_2) var(--border_style) transparent;
		color: var(--text_color_2);
	}
	a:hover {
		/* TODO probably add up to `border_color_5` */
		border-color: var(--border_color_5);
	}
	a:active {
		border-color: var(--border_color_a);
	}
	a.selected {
		border-color: var(--border_color_a);
		color: var(--color_a_6);
	}
</style>
