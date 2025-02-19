<script lang="ts">
	import type {Snippet} from 'svelte';

	import type {Provider_Json} from '$lib/provider.svelte.js';
	import {base} from '$app/paths';
	import type {SvelteHTMLElements} from 'svelte/elements';

	interface Props {
		provider: Provider_Json; // TODO BLOCK Provider, not Provider_Json?
		attrs?: SvelteHTMLElements['a'];
		children?: Snippet;
	}

	const {provider, attrs, children}: Props = $props();
</script>

<a {...attrs} href="{base}/provider/{provider.name}"
	>{#if children}{@render children()}{:else}{provider.title}{/if}</a
>
