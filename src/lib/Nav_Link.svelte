<script lang="ts">
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Snippet} from 'svelte';
	import {base} from '$app/paths';
	import {ensure_end} from '@ryanatkn/belt/string.js';

	interface Props {
		href: string;
		selected?: boolean | undefined;
		show_selected_descendent?: boolean | undefined;
		attrs?: SvelteHTMLElements['a'] | undefined;
		children: Snippet<[selected: boolean, selected_descendent: boolean]>;
	}

	const {
		href: href_prop,
		selected: selected_prop,
		show_selected_descendent = true,
		attrs,
		children,
	}: Props = $props();

	const href = $derived(ensure_end(href_prop, '/'));
	const pathname = $derived(ensure_end(page.url.pathname, '/'));

	const selected = $derived(selected_prop ?? pathname === href);
	const selected_descendent = $derived(
		show_selected_descendent &&
			(selected || href === base + '/' ? false : pathname.startsWith(href)),
	);

	// TODO link styles should have focus always be blue, and active should be thicker
</script>

<!-- 
	transition:slide -->
<a {...attrs} {href} class="nav_link {attrs?.class}" class:selected class:selected_descendent
	>{@render children(selected, selected_descendent)}</a
>

<style>
	.nav_link {
		display: flex;
		align-items: center;
		padding: var(--space_xs2) var(--space_sm);
		text-decoration: none;
		border: var(--border_width_2) var(--border_style) transparent;
		color: var(--text_color_2);
		font-weight: 600;
		white-space: nowrap;
	}
	.nav_link:hover {
		border-color: var(--border_color_5);
	}
	.nav_link:active {
		border-color: var(--border_color_a);
	}
	.nav_link.selected {
		border-color: var(--border_color_a);
		color: var(--color_a_6);
	}
	.nav_link.selected_descendent {
		border-color: var(--border_color_5);
	}
</style>
