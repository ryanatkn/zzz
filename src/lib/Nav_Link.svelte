<script lang="ts">
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Snippet} from 'svelte';
	import {base} from '$app/paths';

	interface Props {
		href: string;
		attrs?: SvelteHTMLElements['a'];
		children: Snippet<[selected: boolean, selected_descendent: boolean]>;
	}

	const {href, attrs, children}: Props = $props();

	const selected = $derived(page.url.pathname === href);
	const selected_descendent = $derived(
		selected || href === base + '/' ? false : page.url.pathname.startsWith(href),
	);

	// TODO link styles should have focus always be blue, and active should be thicker
</script>

<a {...attrs} {href} class="nav_link {attrs?.class}" class:selected class:selected_descendent
	>{@render children(selected, selected_descendent)}</a
>

<style>
	a {
		display: flex;
		align-items: center;
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
	a.selected_descendent {
		border-color: var(--border_color_5);
	}
</style>
