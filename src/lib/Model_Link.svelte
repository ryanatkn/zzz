<script lang="ts">
	import type {Snippet} from 'svelte';

	import type {Model_Json} from '$lib/model.svelte.js';
	import {base} from '$app/paths';
	import type {SvelteHTMLElements} from 'svelte/elements';

	interface Props {
		model: Model_Json; // TODO BLOCK Model, not Model_Json?
		attrs?: SvelteHTMLElements['a'];
		children?: Snippet;
	}

	const {model, attrs, children}: Props = $props();
</script>

<a {...attrs} href="{base}/model/{model.name}"
	>{#if children}{@render children()}{:else}{model.name}{/if}</a
>
