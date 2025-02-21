<script lang="ts">
	import type {Snippet} from 'svelte';
	import {base} from '$app/paths';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Provider_Json} from '$lib/provider.svelte.js';
	import {SYMBOL_PROVIDER} from '$lib/constants.js';

	interface Props {
		provider: Provider_Json; // TODO BLOCK Provider, not Provider_Json?
		attrs?: SvelteHTMLElements['a'];
		children?: Snippet;
	}

	const {provider, attrs, children}: Props = $props();
</script>

<a {...attrs} href="{base}/providers/{provider.name}"
	>{#if children}{@render children()}{:else}{SYMBOL_PROVIDER} {provider.title}{/if}</a
>
