<script lang="ts">
	import {base} from '$app/paths';
	import type {Snippet} from 'svelte';

	import {hud_context} from './hud.svelte.js';

	interface Props {
		hud?: Snippet;
		children: Snippet;
	}

	const {hud, children}: Props = $props();

	const final_hud: Snippet = $derived(hud ?? hud_context.get() ?? hud_default);
</script>

{@render children()}
<div class="hud">
	{@render final_hud()}
</div>

{#snippet hud_default()}
	<a href="{base}/about" class="size_xl3 justify_self_end">about</a>
{/snippet}

<style>
	.hud {
		position: fixed;
		bottom: 0;
		left: 0;
		height: var(--input_height);
		width: 100%;
	}
</style>
