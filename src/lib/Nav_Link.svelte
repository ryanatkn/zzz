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
</script>

<a {...attrs} {href} class:selected class:menu_item={true}>{@render children()}</a>

<style>
	a {
		padding: var(--space_xs2) var(--space_md);
		text-decoration: none;
	}
	a:hover {
		background-color: var(--fg_2);
	}
	a.selected {
		background-color: var(--fg_1);
	}
</style>
